import CarpdmCore
import Foundation

public struct GitWorkspaceInspector: GitWorkspaceInspecting {
    public init() {}

    public func summarizeChanges(in rootPath: String) async -> GitWorkspaceSummary {
        guard FileManager.default.fileExists(atPath: URL(fileURLWithPath: rootPath).appendingPathComponent(".git").path) else {
            return GitWorkspaceSummary(isRepository: false)
        }

        do {
            let output = try run(arguments: ["-C", rootPath, "status", "--short"])
            let files = output
                .split(separator: "\n")
                .compactMap { line -> GitChangedFile? in
                    guard line.count >= 4 else { return nil }
                    let status = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
                    let path = String(line.dropFirst(3))
                    return GitChangedFile(path: path, statusCode: status)
                }
            return GitWorkspaceSummary(isRepository: true, changedFiles: files, rawStatus: output)
        } catch {
            return GitWorkspaceSummary(isRepository: true, rawStatus: "git status failed: \(error.localizedDescription)")
        }
    }

    private func run(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}

