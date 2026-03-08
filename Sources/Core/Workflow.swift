import Foundation

public enum WorkflowAction: Sendable {
    case startImplementation
    case startPreCommitReview
    case completeTask
}

public enum OrchestrationStage: String, Codable, Sendable {
    case idle
    case waitingForPlanApproval
    case implementing
    case waitingForCoreLogicApproval
    case reviewing
    case waitingForPreCommitApproval
    case completed
}

public struct OrchestrationStateMachine {
    public static func stage(for task: TaskDocument) -> OrchestrationStage {
        if task.status == .done {
            return .completed
        }
        if task.metadata.approvalState[.preCommit] == .approved {
            return .reviewing
        }
        if task.metadata.approvalState[.coreLogicReview] == .pending,
           !task.body.agentOutputs.isEmpty {
            return .waitingForCoreLogicApproval
        }
        if task.metadata.approvalState[.planReview] == .pending,
           !task.body.plan.isEmpty {
            return .waitingForPlanApproval
        }
        if task.metadata.approvalState[.coreLogicReview] == .approved,
           task.metadata.approvalState[.preCommit] == .pending {
            return .waitingForPreCommitApproval
        }
        return .idle
    }
}

