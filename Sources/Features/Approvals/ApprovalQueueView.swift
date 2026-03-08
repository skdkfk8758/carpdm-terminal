import CarpdmCore
import SwiftUI

public struct ApprovalQueueView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Approval Queue")
                .font(.headline)
            if viewModel.pendingApprovals.isEmpty {
                Text("No pending approvals")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.pendingApprovals) { approval in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(approval.displayName)
                            Text("Required to advance the workflow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Approve") {
                            viewModel.approve(approval)
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

