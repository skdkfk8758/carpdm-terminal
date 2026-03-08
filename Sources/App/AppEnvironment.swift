import CarpdmCore
import CarpdmFeatures
import CarpdmInfrastructure
import Foundation

@MainActor
enum AppEnvironment {
    static func makeViewModel() throws -> WorkspaceViewModel {
        let appPaths = try AppPaths.live()
        let database = try AppDatabase(url: appPaths.databaseURL)

        let projectStore = SQLiteProjectStore(dbQueue: database.dbQueue)
        let workspaceStateStore = SQLiteWorkspaceStateStore(dbQueue: database.dbQueue)
        let sessionStore = SQLiteAgentSessionRuntimeStore(dbQueue: database.dbQueue)
        let cliHealthStore = SQLiteCLIHealthStore(dbQueue: database.dbQueue)
        let taskStore = MarkdownTaskStore()
        let noteStore = taskStore as NoteStore
        let bootstrapper = DefaultVaultBootstrapper()
        let agentAdapter = DefaultAgentAdapter(cliHealthStore: cliHealthStore)
        let gitInspector = GitWorkspaceInspector()
        let notificationScheduler = NotificationSchedulerFactory.makeDefault()
        let approvalCoordinator = DefaultApprovalCoordinator()
        let orchestrator = TaskOrchestrator(
            taskStore: taskStore,
            noteStore: noteStore,
            sessionStore: sessionStore,
            agentAdapter: agentAdapter,
            approvalCoordinator: approvalCoordinator,
            gitInspector: gitInspector,
            notificationScheduler: notificationScheduler
        )

        return WorkspaceViewModel(
            projectStore: projectStore,
            workspaceStateStore: workspaceStateStore,
            taskStore: taskStore,
            noteStore: noteStore,
            bootstrapper: bootstrapper,
            sessionStore: sessionStore,
            agentAdapter: agentAdapter,
            vaultWatcherFactory: DefaultVaultWatcherFactory(),
            gitInspector: gitInspector,
            orchestrator: orchestrator
        )
    }
}
