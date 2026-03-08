import CarpdmCore
import Foundation
import GRDB

private enum StoreCoding {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "StoreCoding", code: 1)
        }
        return string
    }

    static func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        try decoder.decode(type, from: Data(string.utf8))
    }
}

private struct ProjectRow: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String
    var rootPath: String
    var vaultPath: String
    var createdAt: String
    var lastOpenedAt: String
    var defaultAgentsJSON: String
    var uiStateJSON: String

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let rootPath = Column(CodingKeys.rootPath)
        static let lastOpenedAt = Column(CodingKeys.lastOpenedAt)
    }
}

private struct WorkspaceStateRow: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var selectedProjectID: String?
    var selectedTaskID: String?
    var selectedSection: String
    var terminalHeight: Double
}

private struct AgentSessionRuntimeRow: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var taskID: String
    var agentType: String
    var role: String
    var status: String
    var startedAt: String
    var endedAt: String?
    var transcriptPath: String?
    var summary: String
}

private struct CLIHealthRow: Codable, FetchableRecord, PersistableRecord {
    var agentType: String
    var isAvailable: Bool
    var commandPath: String?
    var checkedAt: String
}

public final class SQLiteProjectStore: ProjectStore {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func fetchProjects() throws -> [Project] {
        try dbQueue.read { db in
            try ProjectRow
                .order(ProjectRow.Columns.lastOpenedAt.desc)
                .fetchAll(db)
                .map(Self.project(from:))
        }
    }

    public func saveProject(_ project: Project) throws {
        try dbQueue.write { db in
            try Self.row(from: project).save(db)
        }
    }

    public func touchProject(id: UUID, at date: Date) throws {
        try dbQueue.write { db in
            _ = try ProjectRow
                .filter(ProjectRow.Columns.id == id.uuidString)
                .updateAll(db, [Column("lastOpenedAt").set(to: CarpdmDateCodec.string(from: date))])
        }
    }

    private static func row(from project: Project) throws -> ProjectRow {
        ProjectRow(
            id: project.id.uuidString,
            name: project.name,
            rootPath: project.rootPath,
            vaultPath: project.vaultPath,
            createdAt: CarpdmDateCodec.string(from: project.createdAt),
            lastOpenedAt: CarpdmDateCodec.string(from: project.lastOpenedAt),
            defaultAgentsJSON: try StoreCoding.encode(project.defaultAgents),
            uiStateJSON: try StoreCoding.encode(project.uiState)
        )
    }

    private static func project(from row: ProjectRow) throws -> Project {
        Project(
            id: UUID(uuidString: row.id) ?? UUID(),
            name: row.name,
            rootPath: row.rootPath,
            vaultPath: row.vaultPath,
            createdAt: CarpdmDateCodec.date(from: row.createdAt),
            lastOpenedAt: CarpdmDateCodec.date(from: row.lastOpenedAt),
            defaultAgents: try StoreCoding.decode([AgentType].self, from: row.defaultAgentsJSON),
            uiState: try StoreCoding.decode(ProjectUIState.self, from: row.uiStateJSON)
        )
    }
}

public final class SQLiteWorkspaceStateStore: WorkspaceStateStore {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func fetchState() throws -> WorkspaceState {
        try dbQueue.read { db in
            guard let row = try WorkspaceStateRow.fetchOne(db, key: 1) else {
                return WorkspaceState()
            }
            return WorkspaceState(
                selectedProjectID: row.selectedProjectID.flatMap(UUID.init(uuidString:)),
                selectedTaskID: row.selectedTaskID,
                selectedSection: SidebarSection(rawValue: row.selectedSection) ?? .backlog,
                terminalHeight: row.terminalHeight
            )
        }
    }

    public func saveState(_ state: WorkspaceState) throws {
        try dbQueue.write { db in
            try WorkspaceStateRow(
                id: 1,
                selectedProjectID: state.selectedProjectID?.uuidString,
                selectedTaskID: state.selectedTaskID,
                selectedSection: state.selectedSection.rawValue,
                terminalHeight: state.terminalHeight
            ).save(db)
        }
    }
}

public final class SQLiteAgentSessionRuntimeStore: AgentSessionRuntimeStore {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func fetchSessions(taskID: String?) throws -> [AgentSessionRecord] {
        try dbQueue.read { db in
            let rows: [AgentSessionRuntimeRow]
            if let taskID {
                rows = try AgentSessionRuntimeRow.filter(Column("taskID") == taskID).fetchAll(db)
            } else {
                rows = try AgentSessionRuntimeRow.fetchAll(db)
            }
            return rows
                .sorted { $0.startedAt > $1.startedAt }
                .map {
                    AgentSessionRecord(
                        id: UUID(uuidString: $0.id) ?? UUID(),
                        taskID: $0.taskID,
                        agentType: AgentType(rawValue: $0.agentType) ?? .claude,
                        role: AgentRole(rawValue: $0.role) ?? .lead,
                        status: AgentSessionStatus(rawValue: $0.status) ?? .failed,
                        startedAt: CarpdmDateCodec.date(from: $0.startedAt),
                        endedAt: $0.endedAt.map(CarpdmDateCodec.date(from:)),
                        transcriptPath: $0.transcriptPath,
                        summary: $0.summary
                    )
                }
        }
    }

    public func saveSession(_ session: AgentSessionRecord) throws {
        try dbQueue.write { db in
            try AgentSessionRuntimeRow(
                id: session.id.uuidString,
                taskID: session.taskID,
                agentType: session.agentType.rawValue,
                role: session.role.rawValue,
                status: session.status.rawValue,
                startedAt: CarpdmDateCodec.string(from: session.startedAt),
                endedAt: session.endedAt.map(CarpdmDateCodec.string(from:)),
                transcriptPath: session.transcriptPath,
                summary: session.summary
            ).save(db)
        }
    }
}

public final class SQLiteCLIHealthStore: CLIHealthStore {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func fetchAll() throws -> [CLIHealth] {
        try dbQueue.read { db in
            try CLIHealthRow.fetchAll(db).map {
                CLIHealth(
                    agent: AgentType(rawValue: $0.agentType) ?? .claude,
                    isAvailable: $0.isAvailable,
                    commandPath: $0.commandPath,
                    checkedAt: CarpdmDateCodec.date(from: $0.checkedAt)
                )
            }
        }
    }

    public func save(_ health: CLIHealth) throws {
        try dbQueue.write { db in
            try CLIHealthRow(
                agentType: health.agent.rawValue,
                isAvailable: health.isAvailable,
                commandPath: health.commandPath,
                checkedAt: CarpdmDateCodec.string(from: health.checkedAt)
            ).save(db)
        }
    }
}

