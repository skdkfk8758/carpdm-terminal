import CarpdmCore
import Foundation
import SwiftTerm

public enum AgentAdapterError: LocalizedError {
    case unavailable(AgentType)

    public var errorDescription: String? {
        switch self {
        case .unavailable(let agent):
            "\(agent.displayName) CLI is not installed."
        }
    }
}

public final class LocalProcessRunner: NSObject, LocalProcessDelegate {
    public struct CommandResult {
        public var transcript: String
        public var summary: String
        public var exitCode: Int32?
    }

    private var process: LocalProcess?
    private var transcript = ""
    private var continuation: CheckedContinuation<CommandResult, Never>?

    public override init() {
        super.init()
    }

    public func run(_ command: TerminalCommand) async -> CommandResult {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let process = LocalProcess(delegate: self, dispatchQueue: .main)
            if let logDirectory = command.logDirectory {
                try? FileManager.default.createDirectory(
                    at: URL(fileURLWithPath: logDirectory, isDirectory: true),
                    withIntermediateDirectories: true
                )
                process.setHostLogging(directory: logDirectory)
            }
            self.process = process
            transcript = ""
            process.startProcess(
                executable: command.executable,
                args: command.arguments,
                environment: command.environment,
                currentDirectory: command.currentDirectory
            )
            if let bootInput = command.bootInput {
                process.send(data: Array(bootInput.utf8)[...])
            }
        }
    }

    public func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        let lines = transcript
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        continuation?.resume(
            returning: CommandResult(
                transcript: transcript,
                summary: lines.suffix(12).joined(separator: "\n"),
                exitCode: exitCode
            )
        )
        continuation = nil
        process = nil
    }

    public func dataReceived(slice: ArraySlice<UInt8>) {
        transcript += String(decoding: slice, as: UTF8.self)
    }

    public func getWindowSize() -> winsize {
        winsize(ws_row: 40, ws_col: 140, ws_xpixel: 0, ws_ypixel: 0)
    }
}

public actor DefaultAgentAdapter: AgentAdapter {
    private let cliHealthStore: CLIHealthStore?

    public init(cliHealthStore: CLIHealthStore? = nil) {
        self.cliHealthStore = cliHealthStore
    }

    public func healthCheck(for agent: AgentType) async -> CLIHealth {
        let health = Self.resolve(agent: agent)
        try? cliHealthStore?.save(health)
        return health
    }

    public func run(_ request: AgentRunRequest) async throws -> AgentRunResult {
        let health = await healthCheck(for: request.agent)
        guard health.isAvailable else {
            throw AgentAdapterError.unavailable(request.agent)
        }

        let sessionDirectory = URL(fileURLWithPath: request.project.rootPath, isDirectory: true)
            .appendingPathComponent(".carpdm/runtime/sessions/\(request.task.id)/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)

        let startedAt = Date()
        let command = TerminalCommand(
            title: request.agent.displayName,
            executable: "/bin/zsh",
            arguments: ["-lc", health.commandPath ?? request.agent.commandName],
            currentDirectory: request.project.rootPath,
            bootInput: request.prompt + "\n",
            logDirectory: sessionDirectory.path
        )

        let runner = LocalProcessRunner()
        let result = await runner.run(command)

        let transcriptPath = sessionDirectory.appendingPathComponent("transcript.txt")
        try result.transcript.write(to: transcriptPath, atomically: true, encoding: .utf8)

        let session = AgentSessionRecord(
            taskID: request.task.id,
            agentType: request.agent,
            role: request.role,
            status: (result.exitCode ?? 1) == 0 ? .completed : .failed,
            startedAt: startedAt,
            endedAt: Date(),
            transcriptPath: transcriptPath.path,
            summary: result.summary
        )

        return AgentRunResult(session: session, transcript: result.transcript)
    }

    private static func resolve(agent: AgentType) -> CLIHealth {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [agent.commandName]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if process.terminationStatus == 0, !output.isEmpty {
                return CLIHealth(agent: agent, isAvailable: true, commandPath: output)
            }
        } catch {}

        return CLIHealth(agent: agent, isAvailable: false, commandPath: nil)
    }
}
