import CarpdmCore
import CarpdmInfrastructure
import Testing

@Test
func taskMarkdownRoundTripPreservesFields() throws {
    let task = TaskDocument(
        metadata: TaskFrontmatter(
            id: "task-001",
            title: "Bootstrap Workspace",
            status: .inProgress,
            priority: .high,
            supportAgents: [.codex],
            linkedNotePaths: ["01_current_context.md"],
            linkedFilePaths: ["Sources/App/CarpdmTerminalApp.swift"],
            approvalState: ApprovalState(statuses: [.planReview: .approved, .coreLogicReview: .pending])
        ),
        body: TaskBody(
            goal: "Create the initial application shell",
            background: "Empty workspace",
            acceptanceCriteria: "App opens and shows workspace panes",
            plan: "1. Create targets\n2. Add views",
            agentOutputs: "Claude produced the base plan",
            reviewNotes: "Need to validate state restoration",
            finalResult: "Pending"
        ),
        relativePath: "backlog/in_progress/task-001-bootstrap-workspace.md"
    )
    let codec = TaskMarkdownCodec()
    let markdown = try codec.render(task)
    let parsed = try codec.parse(contents: markdown, relativePath: task.relativePath)

    #expect(parsed.metadata.id == task.metadata.id)
    #expect(parsed.metadata.title == task.metadata.title)
    #expect(parsed.metadata.status == .inProgress)
    #expect(parsed.metadata.priority == .high)
    #expect(parsed.metadata.supportAgents == [.codex])
    #expect(parsed.body.goal == task.body.goal)
    #expect(parsed.body.plan == task.body.plan)
    #expect(parsed.metadata.approvalState[.planReview] == .approved)
}
