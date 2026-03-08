import CarpdmCore
import Foundation
import Yams

struct TaskFrontmatterYAML: Codable {
    var id: String
    var title: String
    var status: String
    var priority: String
    var created_at: String
    var updated_at: String
    var author: String
    var lead_agent: String
    var support_agents: [String]
    var linked_note_paths: [String]
    var linked_file_paths: [String]
    var approval_state: [String: String]
}

public struct TaskMarkdownCodec {
    private let encoder = YAMLEncoder()
    private let decoder = YAMLDecoder()

    public init() {}

    public func render(_ task: TaskDocument) throws -> String {
        let yaml = TaskFrontmatterYAML(
            id: task.id,
            title: task.title,
            status: task.metadata.status.rawValue,
            priority: task.metadata.priority.rawValue,
            created_at: CarpdmDateCodec.string(from: task.metadata.createdAt),
            updated_at: CarpdmDateCodec.string(from: task.metadata.updatedAt),
            author: task.metadata.author,
            lead_agent: task.metadata.leadAgent.rawValue,
            support_agents: task.metadata.supportAgents.map(\.rawValue),
            linked_note_paths: task.metadata.linkedNotePaths,
            linked_file_paths: task.metadata.linkedFilePaths,
            approval_state: Dictionary(
                uniqueKeysWithValues: ApprovalType.allCases.map {
                    ($0.rawValue, task.metadata.approvalState[$0].rawValue)
                }
            )
        )

        let frontmatter = try encoder.encode(yaml).trimmingTrailingNewlines()
        return """
        ---
        \(frontmatter)
        ---

        # \(task.title)

        ## Goal
        \(task.body.goal)

        ## Background
        \(task.body.background)

        ## Acceptance Criteria
        \(task.body.acceptanceCriteria)

        ## Plan
        \(task.body.plan)

        ## Agent Outputs
        \(task.body.agentOutputs)

        ## Review Notes
        \(task.body.reviewNotes)

        ## Final Result
        \(task.body.finalResult)
        """
    }

    public func parse(contents: String, relativePath: String) throws -> TaskDocument {
        let (frontmatterText, bodyText) = try split(contents: contents)
        let yaml = try decoder.decode(TaskFrontmatterYAML.self, from: frontmatterText)
        let body = parseBody(bodyText)
        let approvalState = ApprovalState(
            statuses: Dictionary(
                uniqueKeysWithValues: yaml.approval_state.compactMap { key, value in
                    guard let type = ApprovalType(rawValue: key),
                          let status = ApprovalStatus(rawValue: value) else {
                        return nil
                    }
                    return (type, status)
                }
            )
        )

        let metadata = TaskFrontmatter(
            id: yaml.id,
            title: yaml.title,
            status: TaskStatus(rawValue: yaml.status) ?? .inbox,
            priority: TaskPriority(rawValue: yaml.priority) ?? .medium,
            createdAt: CarpdmDateCodec.date(from: yaml.created_at),
            updatedAt: CarpdmDateCodec.date(from: yaml.updated_at),
            author: yaml.author,
            leadAgent: AgentType(rawValue: yaml.lead_agent) ?? .claude,
            supportAgents: yaml.support_agents.compactMap(AgentType.init(rawValue:)),
            linkedNotePaths: yaml.linked_note_paths,
            linkedFilePaths: yaml.linked_file_paths,
            approvalState: approvalState
        )

        return TaskDocument(metadata: metadata, body: body, relativePath: relativePath)
    }

    private func split(contents: String) throws -> (String, String) {
        let separator = "\n---\n"
        guard contents.hasPrefix("---\n") else {
            throw NSError(domain: "TaskMarkdownCodec", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing YAML frontmatter"])
        }
        let remainder = String(contents.dropFirst(4))
        guard let range = remainder.range(of: separator) else {
            throw NSError(domain: "TaskMarkdownCodec", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed YAML frontmatter"])
        }
        let frontmatter = String(remainder[..<range.lowerBound])
        let body = String(remainder[range.upperBound...])
        return (frontmatter, body)
    }

    private func parseBody(_ body: String) -> TaskBody {
        let lines = body.components(separatedBy: .newlines)
        var currentSection: String?
        var buffers: [String: [String]] = [:]

        for line in lines {
            if line.hasPrefix("## ") {
                currentSection = String(line.dropFirst(3))
                buffers[currentSection ?? ""] = []
                continue
            }
            guard let currentSection else { continue }
            buffers[currentSection, default: []].append(line)
        }

        func string(_ title: String) -> String {
            buffers[title, default: []]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return TaskBody(
            goal: string("Goal"),
            background: string("Background"),
            acceptanceCriteria: string("Acceptance Criteria"),
            plan: string("Plan"),
            agentOutputs: string("Agent Outputs"),
            reviewNotes: string("Review Notes"),
            finalResult: string("Final Result")
        )
    }
}

