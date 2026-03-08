import CarpdmCore
import Foundation

public final class MarkdownTaskStore: TaskStore, NoteStore {
    private let fileManager: FileManager
    private let codec: TaskMarkdownCodec

    public init(fileManager: FileManager = .default, codec: TaskMarkdownCodec = .init()) {
        self.fileManager = fileManager
        self.codec = codec
    }

    public func listTasks(in project: Project) throws -> [TaskDocument] {
        let backlogRoot = vaultURL(for: project).appendingPathComponent("backlog")
        var tasks: [TaskDocument] = []

        for status in TaskStatus.allCases {
            let statusURL = backlogRoot.appendingPathComponent(status.folderName)
            guard let enumerator = fileManager.enumerator(at: statusURL, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "md" {
                let relativePath = fileURL.path.replacingOccurrences(of: project.vaultPath + "/", with: "")
                let contents = try String(contentsOf: fileURL, encoding: .utf8)
                var task = try codec.parse(contents: contents, relativePath: relativePath)
                if task.metadata.status != status {
                    task.metadata.status = status
                }
                tasks.append(task)
            }
        }

        return tasks.sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
    }

    public func loadTask(id: String, in project: Project) throws -> TaskDocument {
        guard let task = try listTasks(in: project).first(where: { $0.id == id }) else {
            throw NSError(domain: "MarkdownTaskStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
        return task
    }

    public func createTask(
        in project: Project,
        title: String,
        description: String,
        priority: TaskPriority,
        leadAgent: AgentType,
        supportAgents: [AgentType]
    ) throws -> TaskDocument {
        let id = "task-\(CarpdmDateCodec.string(from: Date()).replacingOccurrences(of: ":", with: "-"))"
        let metadata = TaskFrontmatter(
            id: id,
            title: title,
            status: .inbox,
            priority: priority,
            leadAgent: leadAgent,
            supportAgents: supportAgents
        )
        let body = TaskBody(goal: description)
        let relativePath = relativeTaskPath(id: id, title: title, status: .inbox)
        let task = TaskDocument(metadata: metadata, body: body, relativePath: relativePath)
        return try saveTask(task, in: project)
    }

    public func saveTask(_ task: TaskDocument, in project: Project) throws -> TaskDocument {
        var updated = task
        updated.metadata.updatedAt = Date()
        let relativePath = relativeTaskPath(id: updated.id, title: updated.title, status: updated.metadata.status)
        updated.relativePath = relativePath
        let url = vaultURL(for: project).appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let content = try codec.render(updated)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return updated
    }

    public func moveTask(id: String, to status: TaskStatus, in project: Project) throws -> TaskDocument {
        var task = try loadTask(id: id, in: project)
        let oldURL = vaultURL(for: project).appendingPathComponent(task.relativePath)
        task.metadata.status = status
        task.metadata.updatedAt = Date()
        let newRelativePath = relativeTaskPath(id: task.id, title: task.title, status: status)
        let newURL = vaultURL(for: project).appendingPathComponent(newRelativePath)
        try fileManager.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let content = try codec.render(task)
        if fileManager.fileExists(atPath: oldURL.path) {
            try fileManager.removeItem(at: oldURL)
        }
        try content.write(to: newURL, atomically: true, encoding: .utf8)
        task.relativePath = newRelativePath
        return task
    }

    public func noteContents(at relativePath: String, in project: Project) throws -> String {
        let url = vaultURL(for: project).appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func listNotes(in project: Project) throws -> [VaultNote] {
        let includeRoots = [
            "00_project_overview.md",
            "01_current_context.md",
            "02_architecture.md",
            "notes",
            "decisions",
            "retrospectives"
        ]

        var notes: [VaultNote] = []
        for root in includeRoots {
            let url = vaultURL(for: project).appendingPathComponent(root)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
                    continue
                }
                for case let fileURL as URL in enumerator where fileURL.pathExtension == "md" {
                    let relativePath = fileURL.path.replacingOccurrences(of: project.vaultPath + "/", with: "")
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    notes.append(VaultNote(relativePath: relativePath, title: fileURL.deletingPathExtension().lastPathComponent, content: content))
                }
            } else {
                let content = try String(contentsOf: url, encoding: .utf8)
                let relativePath = url.lastPathComponent
                notes.append(VaultNote(relativePath: relativePath, title: url.deletingPathExtension().lastPathComponent, content: content))
            }
        }

        return notes.sorted { $0.relativePath < $1.relativePath }
    }

    public func loadNote(at relativePath: String, in project: Project) throws -> VaultNote {
        let content = try noteContents(at: relativePath, in: project)
        return VaultNote(relativePath: relativePath, title: URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent, content: content)
    }

    private func vaultURL(for project: Project) -> URL {
        URL(fileURLWithPath: project.vaultPath, isDirectory: true)
    }

    private func relativeTaskPath(id: String, title: String, status: TaskStatus) -> String {
        "backlog/\(status.folderName)/\(id)-\(title.slugified()).md"
    }
}

