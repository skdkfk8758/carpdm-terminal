import AppKit
import CarpdmCore
import Foundation

@MainActor
public final class WorkspaceViewModel: ObservableObject {
    @Published public private(set) var projects: [Project] = []
    @Published public var selectedProject: Project?
    @Published public var tasks: [TaskDocument] = []
    @Published public var selectedTaskDraft: TaskDocument?
    @Published public var notes: [VaultNote] = []
    @Published public var currentContext: String = ""
    @Published public var sessions: [AgentSessionRecord] = []
    @Published public var gitSummary: GitWorkspaceSummary = .init(isRepository: false)
    @Published public var cliHealth: [AgentType: CLIHealth] = [:]
    @Published public var terminalTabs: [TerminalLogTab] = [
        TerminalLogTab(id: "claude", title: "Claude"),
        TerminalLogTab(id: "codex", title: "Codex"),
        TerminalLogTab(id: "gemini", title: "Gemini"),
        TerminalLogTab(id: "run-logs", title: "Run Logs")
    ]
    @Published public var selectedTerminalTabID: String = "shell"
    @Published public var workspaceState: WorkspaceState = .init()
    @Published public var isRunning: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var isCommandPalettePresented: Bool = false

    private let projectStore: ProjectStore
    private let workspaceStateStore: WorkspaceStateStore
    private let taskStore: TaskStore
    private let noteStore: NoteStore
    private let bootstrapper: VaultBootstrapping
    private let sessionStore: AgentSessionRuntimeStore
    private let agentAdapter: AgentAdapter
    private let vaultWatcherFactory: VaultWatcherFactory
    private let gitInspector: GitWorkspaceInspecting
    private let orchestrator: TaskOrchestrator
    private var watcher: (any VaultWatching)?

    public init(
        projectStore: ProjectStore,
        workspaceStateStore: WorkspaceStateStore,
        taskStore: TaskStore,
        noteStore: NoteStore,
        bootstrapper: VaultBootstrapping,
        sessionStore: AgentSessionRuntimeStore,
        agentAdapter: AgentAdapter,
        vaultWatcherFactory: VaultWatcherFactory,
        gitInspector: GitWorkspaceInspecting,
        orchestrator: TaskOrchestrator
    ) {
        self.projectStore = projectStore
        self.workspaceStateStore = workspaceStateStore
        self.taskStore = taskStore
        self.noteStore = noteStore
        self.bootstrapper = bootstrapper
        self.sessionStore = sessionStore
        self.agentAdapter = agentAdapter
        self.vaultWatcherFactory = vaultWatcherFactory
        self.gitInspector = gitInspector
        self.orchestrator = orchestrator
    }

    public func load() {
        do {
            workspaceState = try workspaceStateStore.fetchState()
            projects = try projectStore.fetchProjects()
            if let selectedProjectID = workspaceState.selectedProjectID,
               let project = projects.first(where: { $0.id == selectedProjectID }) {
                selectProject(project)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func openProjectPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Project"

        if panel.runModal() == .OK, let url = panel.url {
            Task { await createOrOpenProject(at: url) }
        }
    }

    public func createTask(title: String, description: String) {
        guard let project = selectedProject else { return }
        do {
            let task = try taskStore.createTask(
                in: project,
                title: title,
                description: description,
                priority: .medium,
                leadAgent: .claude,
                supportAgents: [.codex, .gemini]
            )
            tasks.insert(task, at: 0)
            selectedTaskDraft = task
            statusMessage = "Created \(task.title)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func saveSelectedTask() {
        guard let project = selectedProject, let selectedTaskDraft else { return }
        do {
            let saved = try taskStore.saveTask(selectedTaskDraft, in: project)
            upsert(task: saved)
            self.selectedTaskDraft = saved
            statusMessage = "Saved \(saved.title)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func updateSelectedTask(_ update: (inout TaskDocument) -> Void) {
        guard var task = selectedTaskDraft else { return }
        update(&task)
        selectedTaskDraft = task
    }

    public func moveTask(_ task: TaskDocument, to status: TaskStatus) {
        guard let project = selectedProject else { return }
        do {
            let moved = try taskStore.moveTask(id: task.id, to: status, in: project)
            reloadTasks(in: project, selecting: moved.id)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func selectTask(_ task: TaskDocument?) {
        selectedTaskDraft = task
        workspaceState.selectedTaskID = task?.id
        persistWorkspaceState()
    }

    public func revealTaskInFinder() {
        guard let project = selectedProject, let task = selectedTaskDraft else { return }
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: project.vaultPath).appendingPathComponent(task.relativePath)
        ])
    }

    public func openProjectInFinder() {
        guard let project = selectedProject else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: project.rootPath))
    }

    public func revealChangedFile(_ file: GitChangedFile) {
        guard let project = selectedProject else { return }
        let url = URL(fileURLWithPath: project.rootPath).appendingPathComponent(file.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func runPlan() {
        guard let project = selectedProject, let task = selectedTaskDraft else { return }
        isRunning = true
        statusMessage = "Running plan..."
        Task {
            do {
                let outcome = try await orchestrator.runPlan(for: task.id, in: project)
                apply(outcome)
                statusMessage = "Plan ready for approval"
            } catch {
                statusMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    public func approve(_ type: ApprovalType) {
        guard let project = selectedProject, let task = selectedTaskDraft else { return }
        do {
            let updated = try orchestrator.approve(type, for: task.id, in: project)
            upsert(task: updated)
            selectedTaskDraft = updated
            statusMessage = "\(type.displayName) approved"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func runImplementation() {
        guard let project = selectedProject, let task = selectedTaskDraft else { return }
        isRunning = true
        statusMessage = "Running implementation..."
        Task {
            do {
                let outcome = try await orchestrator.runImplementation(for: task.id, in: project)
                apply(outcome)
                statusMessage = "Implementation finished, waiting for core logic review"
            } catch {
                statusMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    public func runPreCommitReview() {
        guard let project = selectedProject, let task = selectedTaskDraft else { return }
        isRunning = true
        statusMessage = "Running pre-commit review..."
        Task {
            do {
                let outcome = try await orchestrator.runPreCommitReview(for: task.id, in: project)
                apply(outcome)
                statusMessage = "Review finished, waiting for pre-commit approval"
            } catch {
                statusMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    public func completeSelectedTask() {
        guard let project = selectedProject, let task = selectedTaskDraft else { return }
        do {
            let completed = try orchestrator.completeTask(task.id, in: project)
            reloadTasks(in: project, selecting: completed.id)
            statusMessage = "Task marked done"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func refresh() {
        guard let project = selectedProject else { return }
        Task { await refreshProject(project, preserveSelection: true) }
    }

    public func openCommandPalette() {
        isCommandPalettePresented = true
    }

    public func selectProject(_ project: Project) {
        Task { await selectProjectInternal(project) }
    }

    public func performCommand(_ id: String) {
        isCommandPalettePresented = false
        switch id {
        case "open-project":
            openProjectPicker()
        case "new-task":
            createTask(title: "New Task", description: "")
        case "run-plan":
            runPlan()
        case "run-implementation":
            runImplementation()
        case "run-review":
            runPreCommitReview()
        default:
            break
        }
    }

    public var pendingApprovals: [ApprovalType] {
        guard let task = selectedTaskDraft else { return [] }
        return ApprovalType.allCases.filter { task.metadata.approvalState[$0] == .pending }
    }

    private func createOrOpenProject(at rootURL: URL) async {
        do {
            let project = try bootstrapper.bootstrapProject(at: rootURL, name: nil, defaultAgents: [.claude, .codex, .gemini])
            try projectStore.saveProject(project)
            projects = try projectStore.fetchProjects()
            await selectProjectInternal(project)
            statusMessage = "Opened \(project.name)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func selectProjectInternal(_ project: Project) async {
        do {
            try bootstrapper.ensureProjectLayout(for: project)
            try projectStore.touchProject(id: project.id, at: Date())
            selectedProject = project
            workspaceState.selectedProjectID = project.id
            workspaceState.selectedSection = project.uiState.selectedSection
            workspaceState.terminalHeight = project.uiState.terminalHeight
            persistWorkspaceState()
            watch(project: project)
            await refreshProject(project, preserveSelection: true)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshProject(_ project: Project, preserveSelection: Bool) async {
        reloadTasks(in: project, selecting: preserveSelection ? workspaceState.selectedTaskID : nil)
        do {
            notes = try noteStore.listNotes(in: project)
            currentContext = try taskStore.noteContents(at: "01_current_context.md", in: project)
            sessions = try sessionStore.fetchSessions(taskID: selectedTaskDraft?.id)
        } catch {
            statusMessage = error.localizedDescription
        }

        gitSummary = await gitInspector.summarizeChanges(in: project.rootPath)
        await refreshCLIHealth(project.defaultAgents)
    }

    private func reloadTasks(in project: Project, selecting preferredTaskID: String?) {
        do {
            tasks = try taskStore.listTasks(in: project)
            let selected = tasks.first(where: { $0.id == preferredTaskID }) ?? tasks.first
            selectedTaskDraft = selected
            workspaceState.selectedTaskID = selected?.id
            persistWorkspaceState()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func refreshCLIHealth(_ agents: [AgentType]) async {
        var statuses: [AgentType: CLIHealth] = [:]
        for agent in agents {
            statuses[agent] = await agentAdapter.healthCheck(for: agent)
        }
        cliHealth = statuses
    }

    private func watch(project: Project) {
        watcher?.stop()
        watcher = vaultWatcherFactory.makeWatcher(
            for: URL(fileURLWithPath: project.vaultPath, isDirectory: true)
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        try? watcher?.start()
    }

    private func apply(_ outcome: OrchestrationOutcome) {
        upsert(task: outcome.task)
        selectedTaskDraft = outcome.task
        gitSummary = outcome.gitSummary
        sessions = (try? sessionStore.fetchSessions(taskID: outcome.task.id)) ?? outcome.sessions
        for session in outcome.sessions {
            updateTerminalTabs(with: session)
        }
    }

    private func updateTerminalTabs(with session: AgentSessionRecord) {
        guard let index = terminalTabs.firstIndex(where: { $0.id == session.agentType.rawValue }) else { return }
        var tab = terminalTabs[index]
        let snippet = """
        ## \(session.agentType.displayName) \(session.role.rawValue.capitalized)
        \(session.summary)

        """
        tab.content = snippet + tab.content
        terminalTabs[index] = tab

        if let logIndex = terminalTabs.firstIndex(where: { $0.id == "run-logs" }) {
            var logTab = terminalTabs[logIndex]
            logTab.content = "\(session.agentType.displayName): \(session.summary)\n\n" + logTab.content
            terminalTabs[logIndex] = logTab
        }
    }

    private func upsert(task: TaskDocument) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        tasks.sort { $0.metadata.updatedAt > $1.metadata.updatedAt }
    }

    private func persistWorkspaceState() {
        try? workspaceStateStore.saveState(workspaceState)
    }
}

private final class PreviewProjectStore: ProjectStore {
    private var projects = [
        Project(name: "Preview Workspace", rootPath: "/tmp/preview", vaultPath: "/tmp/preview/.carpdm/vault")
    ]

    func fetchProjects() throws -> [Project] { projects }
    func saveProject(_ project: Project) throws { projects = [project] }
    func touchProject(id: UUID, at date: Date) throws {}
}

private final class PreviewWorkspaceStateStore: WorkspaceStateStore {
    func fetchState() throws -> WorkspaceState { WorkspaceState() }
    func saveState(_ state: WorkspaceState) throws {}
}

private final class PreviewSessionStore: AgentSessionRuntimeStore {
    func fetchSessions(taskID: String?) throws -> [AgentSessionRecord] { [] }
    func saveSession(_ session: AgentSessionRecord) throws {}
}

private final class PreviewHealthStore: CLIHealthStore {
    func fetchAll() throws -> [CLIHealth] { [] }
    func save(_ health: CLIHealth) throws {}
}

private final class PreviewTaskStore: TaskStore, NoteStore {
    private var task = TaskDocument(
        metadata: TaskFrontmatter(id: "task-preview", title: "Preview Task", status: .ready),
        body: TaskBody(goal: "Shape the initial app shell", plan: "Review the task, then create the XcodeGen scaffold."),
        relativePath: "backlog/ready/task-preview-preview-task.md"
    )

    func listTasks(in project: Project) throws -> [TaskDocument] { [task] }
    func loadTask(id: String, in project: Project) throws -> TaskDocument { task }
    func createTask(in project: Project, title: String, description: String, priority: TaskPriority, leadAgent: AgentType, supportAgents: [AgentType]) throws -> TaskDocument { task }
    func saveTask(_ task: TaskDocument, in project: Project) throws -> TaskDocument {
        self.task = task
        return task
    }
    func moveTask(id: String, to status: TaskStatus, in project: Project) throws -> TaskDocument {
        task.metadata.status = status
        return task
    }
    func noteContents(at relativePath: String, in project: Project) throws -> String { "# Current Context\nPreview" }
    func listNotes(in project: Project) throws -> [VaultNote] { [VaultNote(relativePath: "01_current_context.md", title: "Current Context", content: "# Current Context\nPreview")] }
    func loadNote(at relativePath: String, in project: Project) throws -> VaultNote { try listNotes(in: project)[0] }
}

private struct PreviewBootstrapper: VaultBootstrapping {
    func bootstrapProject(at rootURL: URL, name: String?, defaultAgents: [AgentType]) throws -> Project {
        Project(name: name ?? "Preview Workspace", rootPath: rootURL.path, vaultPath: rootURL.appendingPathComponent(".carpdm/vault").path)
    }
    func ensureProjectLayout(for project: Project) throws {}
}

private struct PreviewWatcherFactory: VaultWatcherFactory {
    private final class Watcher: VaultWatching {
        func start() throws {}
        func stop() {}
    }
    func makeWatcher(for vaultURL: URL, onChange: @escaping @Sendable ([String]) -> Void) -> any VaultWatching { Watcher() }
}

private struct PreviewGitInspector: GitWorkspaceInspecting {
    func summarizeChanges(in rootPath: String) async -> GitWorkspaceSummary { .init(isRepository: true) }
}

private actor PreviewAgentAdapter: AgentAdapter {
    func healthCheck(for agent: AgentType) async -> CLIHealth {
        CLIHealth(agent: agent, isAvailable: true, commandPath: "/usr/bin/\(agent.rawValue)")
    }
    func run(_ request: AgentRunRequest) async throws -> AgentRunResult {
        let session = AgentSessionRecord(taskID: request.task.id, agentType: request.agent, role: request.role, status: .completed, summary: "Preview output")
        return AgentRunResult(session: session, transcript: "Preview transcript")
    }
}

private struct PreviewNotificationScheduler: NotificationScheduling {
    func send(title: String, body: String) {}
}

public extension WorkspaceViewModel {
    @MainActor
    static var preview: WorkspaceViewModel {
        let taskStore = PreviewTaskStore()
        let sessionStore = PreviewSessionStore()
        let agentAdapter = PreviewAgentAdapter()
        let orchestrator = TaskOrchestrator(
            taskStore: taskStore,
            noteStore: taskStore,
            sessionStore: sessionStore,
            agentAdapter: agentAdapter,
            approvalCoordinator: DefaultApprovalCoordinator(),
            gitInspector: PreviewGitInspector(),
            notificationScheduler: PreviewNotificationScheduler()
        )
        let viewModel = WorkspaceViewModel(
            projectStore: PreviewProjectStore(),
            workspaceStateStore: PreviewWorkspaceStateStore(),
            taskStore: taskStore,
            noteStore: taskStore,
            bootstrapper: PreviewBootstrapper(),
            sessionStore: sessionStore,
            agentAdapter: agentAdapter,
            vaultWatcherFactory: PreviewWatcherFactory(),
            gitInspector: PreviewGitInspector(),
            orchestrator: orchestrator
        )
        viewModel.load()
        return viewModel
    }
}
