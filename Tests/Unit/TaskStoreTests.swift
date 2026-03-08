import CarpdmCore
import CarpdmInfrastructure
import Foundation
import Testing

@Test
func taskStoreMovesFileAndUpdatesFrontmatterStatus() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let bootstrapper = DefaultVaultBootstrapper()
    let project = try bootstrapper.bootstrapProject(at: root, name: nil, defaultAgents: [.claude])
    let store = MarkdownTaskStore()

    let created = try store.createTask(
        in: project,
        title: "Move Task",
        description: "Verify filesystem move",
        priority: .medium,
        leadAgent: .claude,
        supportAgents: []
    )
    let moved = try store.moveTask(id: created.id, to: .review, in: project)

    #expect(moved.metadata.status == .review)
    #expect(moved.relativePath.contains("backlog/review"))
    let fileURL = URL(fileURLWithPath: project.vaultPath).appendingPathComponent(moved.relativePath)
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(contents.contains("status: review"))
}
