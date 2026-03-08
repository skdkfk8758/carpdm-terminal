import CarpdmCore
import Foundation
import GRDB

public final class AppDatabase {
    public let dbQueue: DatabaseQueue

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        dbQueue = try DatabaseQueue(path: url.path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createProjects") { db in
            try db.create(table: "projects") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("rootPath", .text).notNull().unique()
                table.column("vaultPath", .text).notNull()
                table.column("createdAt", .text).notNull()
                table.column("lastOpenedAt", .text).notNull()
                table.column("defaultAgentsJSON", .text).notNull()
                table.column("uiStateJSON", .text).notNull()
            }
        }

        migrator.registerMigration("createWorkspaceState") { db in
            try db.create(table: "workspace_state") { table in
                table.column("id", .integer).primaryKey()
                table.column("selectedProjectID", .text)
                table.column("selectedTaskID", .text)
                table.column("selectedSection", .text).notNull()
                table.column("terminalHeight", .double).notNull()
            }
        }

        migrator.registerMigration("createAgentSessionsRuntime") { db in
            try db.create(table: "agent_sessions_runtime") { table in
                table.column("id", .text).primaryKey()
                table.column("taskID", .text).notNull().indexed()
                table.column("agentType", .text).notNull()
                table.column("role", .text).notNull()
                table.column("status", .text).notNull()
                table.column("startedAt", .text).notNull()
                table.column("endedAt", .text)
                table.column("transcriptPath", .text)
                table.column("summary", .text).notNull()
            }
        }

        migrator.registerMigration("createCliHealth") { db in
            try db.create(table: "cli_health") { table in
                table.column("agentType", .text).primaryKey()
                table.column("isAvailable", .boolean).notNull()
                table.column("commandPath", .text)
                table.column("checkedAt", .text).notNull()
            }
        }

        return migrator
    }
}
