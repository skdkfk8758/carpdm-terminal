import CarpdmCore
import CarpdmFeatures
import CarpdmInfrastructure
import Foundation
import Testing

private final class MemorySessionStore: AgentSessionRuntimeStore {
    var sessions: [AgentSessionRecord] = []

    func fetchSessions(taskID: String?) throws -> [AgentSessionRecord] {
        if let taskID {
            sessions.filter { $0.taskID == taskID }
        } else {
            sessions
        }
    }

    func saveSession(_ session: AgentSessionRecord) throws {
        sessions.append(session)
    }
}

private actor StubAgentAdapter: AgentAdapter {
    func healthCheck(for agent: AgentType) async -> CLIHealth {
        CLIHealth(agent: agent, isAvailable: true, commandPath: "/usr/bin/\(agent.rawValue)")
    }

    func run(_ request: AgentRunRequest) async throws -> AgentRunResult {
        let summary = "\(request.agent.displayName) handled \(request.role.rawValue)"
        let session = AgentSessionRecord(
            taskID: request.task.id,
            agentType: request.agent,
            role: request.role,
            status: .completed,
            endedAt: Date(),
            transcriptPath: "/tmp/\(UUID().uuidString).txt",
            summary: summary
        )
        return AgentRunResult(session: session, transcript: summary)
    }
}

private struct SilentNotifications: NotificationScheduling {
    func send(title: String, body: String) {}
}

@Test
@MainActor
func orchestratorWritesPlanThenRequiresApprovalBeforeImplementation() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let bootstrapper = DefaultVaultBootstrapper()
    let project = try bootstrapper.bootstrapProject(at: root, name: "Integration", defaultAgents: [.claude, .codex, .gemini])
    let taskStore = MarkdownTaskStore()
    let noteStore = taskStore as NoteStore
    let task = try taskStore.createTask(
        in: project,
        title: "Run integration",
        description: "Exercise orchestration",
        priority: .medium,
        leadAgent: .claude,
        supportAgents: [.codex, .gemini]
    )
    let sessionStore = MemorySessionStore()
    let orchestrator = TaskOrchestrator(
        taskStore: taskStore,
        noteStore: noteStore,
        sessionStore: sessionStore,
        agentAdapter: StubAgentAdapter(),
        approvalCoordinator: DefaultApprovalCoordinator(),
        gitInspector: GitWorkspaceInspector(),
        notificationScheduler: SilentNotifications()
    )

    let planned = try await orchestrator.runPlan(for: task.id, in: project)
    #expect(planned.task.body.plan.contains("Claude handled lead"))
    #expect(planned.task.metadata.approvalState[.planReview] == .pending)

    await #expect(throws: TaskOrchestratorError.self) {
        _ = try await orchestrator.runImplementation(for: task.id, in: project)
    }

    _ = try orchestrator.approve(.planReview, for: task.id, in: project)
    let implemented = try await orchestrator.runImplementation(for: task.id, in: project)
    #expect(implemented.task.metadata.approvalState[.coreLogicReview] == .pending)
    #expect(implemented.sessions.count == 2)
}
