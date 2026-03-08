import CarpdmCore
import CoreServices
import Foundation

public final class FSEventVaultWatcher: VaultWatching {
    private let vaultURL: URL
    private let onChange: @Sendable ([String]) -> Void
    private var stream: FSEventStreamRef?

    public init(vaultURL: URL, onChange: @escaping @Sendable ([String]) -> Void) {
        self.vaultURL = vaultURL
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, pathsPointer, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FSEventVaultWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(pathsPointer, to: NSArray.self) as? [String] ?? []
            watcher.onChange(Array(paths.prefix(Int(count))))
        }

        let paths = [vaultURL.path] as CFArray
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream else {
            throw NSError(domain: "VaultWatcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create FSEvent stream"])
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

public struct DefaultVaultWatcherFactory: VaultWatcherFactory {
    public init() {}

    public func makeWatcher(
        for vaultURL: URL,
        onChange: @escaping @Sendable ([String]) -> Void
    ) -> any VaultWatching {
        FSEventVaultWatcher(vaultURL: vaultURL, onChange: onChange)
    }
}
