import Foundation

public struct AppPaths {
    public let applicationSupportDirectory: URL
    public let databaseURL: URL

    public init(applicationSupportDirectory: URL) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.databaseURL = applicationSupportDirectory.appendingPathComponent("app.sqlite")
    }

    public static func live(fileManager: FileManager = .default) throws -> AppPaths {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("CarpdmTerminal", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return AppPaths(applicationSupportDirectory: directory)
    }
}

