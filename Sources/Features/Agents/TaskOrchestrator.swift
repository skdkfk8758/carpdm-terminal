import CarpdmCore
import Foundation

public enum TaskOrchestratorError: LocalizedError {
    case missingApproval(ApprovalType)

    public var errorDescription: String? {
        switch self {
        case .missingApproval(let approval):
            "\(approval.displayName) approval is required before this step."
        }
    }
}

public struct OrchestrationOutcome: Sendable {
    public var task: TaskDocument
    public var sessions: [AgentSessionRecord]
    public var gitSummary: GitWorkspaceSummary

    public init(task: TaskDocument, sessions: [AgentSessionRecord], gitSummary: GitWorkspaceSummary) {
        self.task = task
        self.sessions = sessions
        self.gitSummary = gitSummary
    }
}

@MainActor
public final class TaskOrchestrator {
    private let taskStore: TaskStore
    private let noteStore: NoteStore
    private let sessionStore: AgentSessionRuntimeStore
    private let agentAdapter: AgentAdapter
    private let approvalCoordinator: ApprovalCoordinating
    private let gitInspector: GitWorkspaceInspecting
    private let notificationScheduler: NotificationScheduling

    public init(
        taskStore: TaskStore,
        noteStore: NoteStore,
        sessionStore: AgentSessionRuntimeStore,
        agentAdapter: AgentAdapter,
        approvalCoordinator: ApprovalCoordinating,
        gitInspector: GitWorkspaceInspecting,
        notificationScheduler: NotificationScheduling
    ) {
        self.taskStore = taskStore
        self.noteStore = noteStore
        self.sessionStore = sessionStore
        self.agentAdapter = agentAdapter
        self.approvalCoordinator = approvalCoordinator
        self.gitInspector = gitInspector
        self.notificationScheduler = notificationScheduler
    }

    public func approve(_ type: ApprovalType, for taskID: String, in project: Project) throws -> TaskDocument {
        let task = try taskStore.loadTask(id: taskID, in: project)
        let updated = approvalCoordinator.applying(.approved, to: type, on: task)
        return try taskStore.saveTask(updated, in: project)
    }

    public func runPlan(for taskID: String, in project: Project) async throws -> OrchestrationOutcome {
        var task = try taskStore.loadTask(id: taskID, in: project)
        let request = AgentRunRequest(
            project: project,
            task: task,
            agent: task.metadata.leadAgent,
            role: .lead,
            prompt: try planPrompt(for: task, in: project)
        )
        let result = try await agentAdapter.run(request)
        try sessionStore.saveSession(result.session)
        try writeSessionSummary(result, phaseTitle: "Plan", task: task, in: project)

        task.body.plan = appendBlock(
            existing: task.body.plan,
            title: "\(result.session.agentType.displayName) Plan",
            content: result.session.summary
        )
        task.metadata.approvalState[.planReview] = .pending
        let savedTask = try taskStore.saveTask(task, in: project)
        notificationScheduler.send(title: "Approval needed", body: "\(savedTask.title) is waiting for plan review.")
        return OrchestrationOutcome(task: savedTask, sessions: [result.session], gitSummary: await gitInspector.summarizeChanges(in: project.rootPath))
    }

    public func runImplementation(for taskID: String, in project: Project) async throws -> OrchestrationOutcome {
        var task = try taskStore.loadTask(id: taskID, in: project)
        if let gate = approvalCoordinator.requiredGate(for: .startImplementation, task: task) {
            throw TaskOrchestratorError.missingApproval(gate)
        }

        var sessions: [AgentSessionRecord] = []
        let gitSummary = await gitInspector.summarizeChanges(in: project.rootPath)
        let agents = await availableImplementationAgents(for: task)

        for agent in agents {
            let request = AgentRunRequest(
                project: project,
                task: task,
                agent: agent,
                role: agent == task.metadata.leadAgent ? .lead : .implementer,
                prompt: try implementationPrompt(for: task, in: project, gitSummary: gitSummary)
            )
            let result = try await agentAdapter.run(request)
            try sessionStore.saveSession(result.session)
            try writeSessionSummary(result, phaseTitle: "Implementation", task: task, in: project)
            sessions.append(result.session)
            task.body.agentOutputs = appendBlock(
                existing: task.body.agentOutputs,
                title: "\(result.session.agentType.displayName) Output",
                content: result.session.summary
            )
        }

        task.metadata.status = .inProgress
        task.metadata.approvalState[.coreLogicReview] = .pending
        let savedTask = try taskStore.saveTask(task, in: project)
        notificationScheduler.send(title: "Approval needed", body: "\(savedTask.title) is waiting for core logic review.")
        return OrchestrationOutcome(task: savedTask, sessions: sessions, gitSummary: gitSummary)
    }

    public func runPreCommitReview(for taskID: String, in project: Project) async throws -> OrchestrationOutcome {
        var task = try taskStore.loadTask(id: taskID, in: project)
        if let gate = approvalCoordinator.requiredGate(for: .startPreCommitReview, task: task) {
            throw TaskOrchestratorError.missingApproval(gate)
        }

        let gitSummary = await gitInspector.summarizeChanges(in: project.rootPath)
        let reviewer = await preferredReviewer(for: task)
        let request = AgentRunRequest(
            project: project,
            task: task,
            agent: reviewer,
            role: .reviewer,
            prompt: try preCommitPrompt(for: task, in: project, gitSummary: gitSummary)
        )
        let result = try await agentAdapter.run(request)
        try sessionStore.saveSession(result.session)
        try writeSessionSummary(result, phaseTitle: "Pre-Commit Review", task: task, in: project)

        task.body.reviewNotes = appendBlock(
            existing: task.body.reviewNotes,
            title: "\(reviewer.displayName) Review",
            content: [result.session.summary, gitSummary.rawStatus]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
        )
        task.metadata.approvalState[.preCommit] = .pending
        let savedTask = try taskStore.saveTask(task, in: project)
        notificationScheduler.send(title: "Approval needed", body: "\(savedTask.title) is waiting for pre-commit approval.")
        return OrchestrationOutcome(task: savedTask, sessions: [result.session], gitSummary: gitSummary)
    }

    public func completeTask(_ taskID: String, in project: Project) throws -> TaskDocument {
        let task = try taskStore.loadTask(id: taskID, in: project)
        if let gate = approvalCoordinator.requiredGate(for: .completeTask, task: task) {
            throw TaskOrchestratorError.missingApproval(gate)
        }

        var updated = task
        updated.metadata.status = .done
        updated.body.finalResult = appendBlock(
            existing: task.body.finalResult,
            title: "Completed",
            content: "Task completed on \(CarpdmDateCodec.string(from: Date()))."
        )
        let saved = try taskStore.saveTask(updated, in: project)
        notificationScheduler.send(title: "Task completed", body: saved.title)
        return try taskStore.moveTask(id: saved.id, to: .done, in: project)
    }

    private func availableImplementationAgents(for task: TaskDocument) async -> [AgentType] {
        var agents: [AgentType] = []
        let leadHealth = await agentAdapter.healthCheck(for: task.metadata.leadAgent)
        if leadHealth.isAvailable {
            agents.append(task.metadata.leadAgent)
        }

        for agent in task.metadata.supportAgents where agent == .codex {
            let health = await agentAdapter.healthCheck(for: agent)
            if health.isAvailable {
                agents.append(agent)
            }
        }

        return agents.isEmpty ? [task.metadata.leadAgent] : agents
    }

    private func preferredReviewer(for task: TaskDocument) async -> AgentType {
        if task.metadata.supportAgents.contains(.gemini),
           (await agentAdapter.healthCheck(for: .gemini)).isAvailable {
            return .gemini
        }
        return task.metadata.leadAgent
    }

    private func planPrompt(for task: TaskDocument, in project: Project) throws -> String {
        let context = try noteStore.loadNote(at: "01_current_context.md", in: project).content
        return """
        You are planning work for task "\(task.title)".

        Goal:
        \(task.body.goal)

        Background:
        \(task.body.background)

        Acceptance Criteria:
        \(task.body.acceptanceCriteria)

        Current Context:
        \(context)

        Produce a concise implementation plan and call out files likely to change.
        """
    }

    private func implementationPrompt(for task: TaskDocument, in project: Project, gitSummary: GitWorkspaceSummary) throws -> String {
        let context = try noteStore.loadNote(at: "01_current_context.md", in: project).content
        return """
        Implement task "\(task.title)".

        Approved plan:
        \(task.body.plan)

        Current context:
        \(context)

        Existing changed files:
        \(gitSummary.rawStatus.isEmpty ? "None" : gitSummary.rawStatus)

        Focus on concrete code changes and verification steps.
        """
    }

    private func preCommitPrompt(for task: TaskDocument, in project: Project, gitSummary: GitWorkspaceSummary) throws -> String {
        let architecture = try noteStore.loadNote(at: "02_architecture.md", in: project).content
        return """
        Review task "\(task.title)" before commit.

        Task outputs:
        \(task.body.agentOutputs)

        Architecture notes:
        \(architecture)

        Git summary:
        \(gitSummary.rawStatus.isEmpty ? "No git repository or no changes." : gitSummary.rawStatus)

        Highlight risks, regressions, and missing checks.
        """
    }

    private func writeSessionSummary(
        _ result: AgentRunResult,
        phaseTitle: String,
        task: TaskDocument,
        in project: Project
    ) throws {
        let directory = URL(fileURLWithPath: project.vaultPath, isDirectory: true)
            .appendingPathComponent("agent_logs/\(task.id)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let timestamp = CarpdmDateCodec.string(from: result.session.startedAt).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(timestamp)-\(result.session.agentType.rawValue)-\(result.session.role.rawValue).md")
        let content = """
        ---
        task_id: \(task.id)
        agent: \(result.session.agentType.rawValue)
        role: \(result.session.role.rawValue)
        started_at: \(CarpdmDateCodec.string(from: result.session.startedAt))
        ended_at: \(CarpdmDateCodec.string(from: result.session.endedAt ?? Date()))
        transcript_path: \(result.session.transcriptPath ?? "")
        ---

        # \(phaseTitle)

        ## Summary
        \(result.session.summary)

        ## Transcript
        ```
        \(result.transcript)
        ```
        """
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func appendBlock(existing: String, title: String, content: String) -> String {
        let block = """
        ### \(title)
        \(content.trimmingCharacters(in: .whitespacesAndNewlines))
        """
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return block
        }
        return "\(existing.trimmingTrailingNewlines())\n\n\(block)"
    }
}
