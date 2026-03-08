import CarpdmCore
import CarpdmFeatures
import Testing

@Test
func approvalCoordinatorBlocksStepsUntilRequiredGateIsApproved() {
    let coordinator = DefaultApprovalCoordinator()
    var task = TaskDocument(
        metadata: TaskFrontmatter(id: "task-approval", title: "Approval Task"),
        body: TaskBody(plan: "Generated plan"),
        relativePath: "backlog/inbox/task-approval.md"
    )

    #expect(coordinator.requiredGate(for: .startImplementation, task: task) == .planReview)

    task = coordinator.applying(.approved, to: .planReview, on: task)
    #expect(coordinator.requiredGate(for: .startImplementation, task: task) == nil)
    #expect(coordinator.requiredGate(for: .startPreCommitReview, task: task) == .coreLogicReview)
}
