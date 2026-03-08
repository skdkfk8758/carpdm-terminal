import CarpdmCore
import CarpdmInfrastructure
import Foundation
import Testing

@Test
func vaultBootstrapperCreatesExpectedLayout() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let bootstrapper = DefaultVaultBootstrapper()
    let project = try bootstrapper.bootstrapProject(at: root, name: "Sample", defaultAgents: [.claude, .codex])

    let expectedPaths = [
        ".carpdm/vault/00_project_overview.md",
        ".carpdm/vault/01_current_context.md",
        ".carpdm/vault/02_architecture.md",
        ".carpdm/vault/backlog/inbox",
        ".carpdm/vault/backlog/ready",
        ".carpdm/vault/backlog/in_progress",
        ".carpdm/vault/backlog/review",
        ".carpdm/vault/backlog/done",
        ".carpdm/runtime/sessions"
    ]

    for path in expectedPaths {
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
    }
    #expect(project.vaultPath.hasSuffix(".carpdm/vault"))
}
