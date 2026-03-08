import CarpdmCore
import Foundation

public final class DefaultVaultBootstrapper: VaultBootstrapping {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func bootstrapProject(at rootURL: URL, name: String?, defaultAgents: [AgentType]) throws -> Project {
        let vaultURL = rootURL.appendingPathComponent(".carpdm/vault", isDirectory: true)
        let runtimeURL = rootURL.appendingPathComponent(".carpdm/runtime/sessions", isDirectory: true)
        let project = Project(
            name: name ?? rootURL.lastPathComponent,
            rootPath: rootURL.path,
            vaultPath: vaultURL.path,
            defaultAgents: defaultAgents
        )
        try ensureProjectLayout(for: project)
        try fileManager.createDirectory(at: runtimeURL, withIntermediateDirectories: true)
        let gitIgnoreURL = rootURL.appendingPathComponent(".carpdm/.gitignore")
        if !fileManager.fileExists(atPath: gitIgnoreURL.path) {
            try "runtime/\n".write(to: gitIgnoreURL, atomically: true, encoding: .utf8)
        }
        return project
    }

    public func ensureProjectLayout(for project: Project) throws {
        let vaultURL = URL(fileURLWithPath: project.vaultPath, isDirectory: true)
        let directories = [
            vaultURL,
            vaultURL.appendingPathComponent("decisions"),
            vaultURL.appendingPathComponent("tasks"),
            vaultURL.appendingPathComponent("backlog/inbox"),
            vaultURL.appendingPathComponent("backlog/ready"),
            vaultURL.appendingPathComponent("backlog/in_progress"),
            vaultURL.appendingPathComponent("backlog/review"),
            vaultURL.appendingPathComponent("backlog/done"),
            vaultURL.appendingPathComponent("agent_logs"),
            vaultURL.appendingPathComponent("notes"),
            vaultURL.appendingPathComponent("retrospectives")
        ]

        try directories.forEach { try fileManager.createDirectory(at: $0, withIntermediateDirectories: true) }

        try seedIfMissing(
            at: vaultURL.appendingPathComponent("00_project_overview.md"),
            content: """
            # Project Overview

            - Name: \(project.name)
            - Root: \(project.rootPath)
            - Default agents: \(project.defaultAgents.map(\.displayName).joined(separator: ", "))
            """
        )

        try seedIfMissing(
            at: vaultURL.appendingPathComponent("01_current_context.md"),
            content: """
            # Current Context

            ## Focus

            ## Open Questions

            ## Next Steps
            """
        )

        try seedIfMissing(
            at: vaultURL.appendingPathComponent("02_architecture.md"),
            content: """
            # Architecture

            ## System Overview

            ## Key Decisions

            ## Risks
            """
        )
    }

    private func seedIfMissing(at url: URL, content: String) throws {
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

