import CarpdmCore
import Foundation

public struct DefaultApprovalCoordinator: ApprovalCoordinating {
    public init() {}

    public func requiredGate(for action: WorkflowAction, task: TaskDocument) -> ApprovalType? {
        switch action {
        case .startImplementation:
            return task.metadata.approvalState[.planReview] == .approved ? nil : .planReview
        case .startPreCommitReview:
            return task.metadata.approvalState[.coreLogicReview] == .approved ? nil : .coreLogicReview
        case .completeTask:
            return task.metadata.approvalState[.preCommit] == .approved ? nil : .preCommit
        }
    }

    public func applying(_ status: ApprovalStatus, to type: ApprovalType, on task: TaskDocument) -> TaskDocument {
        var task = task
        task.metadata.approvalState[type] = status
        task.metadata.updatedAt = Date()
        return task
    }
}

