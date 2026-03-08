import Foundation

public protocol ProjectStore {
    func fetchProjects() throws -> [Project]
    func saveProject(_ project: Project) throws
    func touchProject(id: UUID, at date: Date) throws
}

public protocol WorkspaceStateStore {
    func fetchState() throws -> WorkspaceState
    func saveState(_ state: WorkspaceState) throws
}

public protocol AgentSessionRuntimeStore {
    func fetchSessions(taskID: String?) throws -> [AgentSessionRecord]
    func saveSession(_ session: AgentSessionRecord) throws
}

public protocol CLIHealthStore {
    func fetchAll() throws -> [CLIHealth]
    func save(_ health: CLIHealth) throws
}

public protocol TaskStore {
    func listTasks(in project: Project) throws -> [TaskDocument]
    func loadTask(id: String, in project: Project) throws -> TaskDocument
    func createTask(
        in project: Project,
        title: String,
        description: String,
        priority: TaskPriority,
        leadAgent: AgentType,
        supportAgents: [AgentType]
    ) throws -> TaskDocument
    func saveTask(_ task: TaskDocument, in project: Project) throws -> TaskDocument
    func moveTask(id: String, to status: TaskStatus, in project: Project) throws -> TaskDocument
    func noteContents(at relativePath: String, in project: Project) throws -> String
}

public protocol NoteStore {
    func listNotes(in project: Project) throws -> [VaultNote]
    func loadNote(at relativePath: String, in project: Project) throws -> VaultNote
}

public protocol VaultBootstrapping {
    func bootstrapProject(at rootURL: URL, name: String?, defaultAgents: [AgentType]) throws -> Project
    func ensureProjectLayout(for project: Project) throws
}

public protocol VaultWatching: AnyObject {
    func start() throws
    func stop()
}

public protocol VaultWatcherFactory {
    func makeWatcher(
        for vaultURL: URL,
        onChange: @escaping @Sendable ([String]) -> Void
    ) -> any VaultWatching
}

public protocol ApprovalCoordinating {
    func requiredGate(for action: WorkflowAction, task: TaskDocument) -> ApprovalType?
    func applying(_ status: ApprovalStatus, to type: ApprovalType, on task: TaskDocument) -> TaskDocument
}

public protocol AgentAdapter: Sendable {
    func healthCheck(for agent: AgentType) async -> CLIHealth
    func run(_ request: AgentRunRequest) async throws -> AgentRunResult
}

public protocol GitWorkspaceInspecting: Sendable {
    func summarizeChanges(in rootPath: String) async -> GitWorkspaceSummary
}

public protocol NotificationScheduling {
    func send(title: String, body: String)
}
