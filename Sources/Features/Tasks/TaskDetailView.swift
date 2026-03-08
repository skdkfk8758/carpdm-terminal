import CarpdmCore
import SwiftUI

public struct TaskDetailView: View {
    @ObservedObject var viewModel: WorkspaceViewModel

    public init(viewModel: WorkspaceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let task = viewModel.selectedTaskDraft {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Task title", text: binding(for: \.metadata.title))
                                    .font(.title2.weight(.semibold))
                                HStack(spacing: 10) {
                                    Text(task.id)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Text(task.status.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                Button("Save") {
                                    viewModel.saveSelectedTask()
                                }
                                Button("Reveal in Finder") {
                                    viewModel.revealTaskInFinder()
                                }
                            }
                        }

                        actionBar

                        sectionEditor("Goal", text: binding(for: \.body.goal))
                        sectionEditor("Background", text: binding(for: \.body.background))
                        sectionEditor("Acceptance Criteria", text: binding(for: \.body.acceptanceCriteria))
                        sectionEditor("Plan", text: binding(for: \.body.plan))
                        sectionEditor("Agent Outputs", text: binding(for: \.body.agentOutputs))
                        sectionEditor("Review Notes", text: binding(for: \.body.reviewNotes))
                        sectionEditor("Final Result", text: binding(for: \.body.finalResult))
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView("No Task Selected", systemImage: "checklist", description: Text("Select a task from the backlog board."))
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("Run Plan") { viewModel.runPlan() }
            Button("Approve Plan") { viewModel.approve(.planReview) }
            Button("Run Implementation") { viewModel.runImplementation() }
            Button("Approve Core Logic") { viewModel.approve(.coreLogicReview) }
            Button("Run Pre-Commit Review") { viewModel.runPreCommitReview() }
            Button("Approve Pre-Commit") { viewModel.approve(.preCommit) }
            Button("Mark Done") { viewModel.completeSelectedTask() }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func sectionEditor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private func binding(for keyPath: WritableKeyPath<TaskDocument, String>) -> Binding<String> {
        Binding(
            get: { viewModel.selectedTaskDraft?[keyPath: keyPath] ?? "" },
            set: { newValue in
                viewModel.updateSelectedTask { $0[keyPath: keyPath] = newValue }
            }
        )
    }
}

