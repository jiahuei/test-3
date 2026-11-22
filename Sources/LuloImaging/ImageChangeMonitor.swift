import CoreServices
import Foundation
import LuloCore

/// Watches the current authorized folder, or checks just the opened file when sibling access was declined.
public final class ImageChangeMonitor {
    private var stream: FSEventStreamRef?
    private var fileTask: Task<Void, Never>?

    public var isActive: Bool { stream != nil || fileTask != nil }

    public init(
        fileAccess: FileAccess?, folderAccess: FileAccess?, watchFolder: URL? = nil,
        onChange: @escaping @Sendable () -> Void
    ) {
        if let folderAccess {
            let callback = Callback(access: folderAccess, folder: watchFolder ?? folderAccess.url, onChange: onChange)
            var context = FSEventStreamContext(
                version: 0, info: Unmanaged.passUnretained(callback).toOpaque(),
                retain: { pointer in
                    guard let pointer else { return nil }
                    _ = Unmanaged<Callback>.fromOpaque(pointer).retain()
                    return pointer
                },
                release: { pointer in
                    guard let pointer else { return }
                    Unmanaged<Callback>.fromOpaque(pointer).release()
                }, copyDescription: nil)
            stream = FSEventStreamCreate(
                nil,
                { _, info, count, paths, flags, _ in
                    guard let info else { return }
                    let callback = Unmanaged<Callback>.fromOpaque(info).takeUnretainedValue()
                    let paths = unsafeBitCast(paths, to: NSArray.self) as! [String]
                    for index in 0..<count {
                        let url = URL(fileURLWithPath: paths[index]).standardizedFileURL
                        let mustRescan =
                            flags[index]
                            & UInt32(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagRootChanged) != 0
                        // Standardizing a deleted file cannot remove /private. Its existing parent can,
                        // so normalize that directory before comparing it with the watched folder.
                        let parent = url.deletingLastPathComponent().standardizedFileURL
                        // A direct child can be an image, a folder, or an item removed by a rename.
                        // Refresh for all of them so both gallery tiles and navigation stay current.
                        if mustRescan || url == callback.folder || parent == callback.folder {
                            callback.onChange()
                            break
                        }
                    }
                },
                &context, [callback.folder.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.3,
                UInt32(
                    kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
                        | kFSEventStreamCreateFlagWatchRoot))
            if let stream {
                FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
                if !FSEventStreamStart(stream) {
                    FSEventStreamInvalidate(stream)
                    FSEventStreamRelease(stream)
                    self.stream = nil
                }
            }
        } else {
            guard let fileAccess else { return }
            // FSEvents watches directories. Checking one file avoids observing unauthorized siblings
            // and follows atomic replacements/recreation, which a watch on the old inode cannot do.
            fileTask = Task.detached(priority: .utility) {
                defer { withExtendedLifetime(fileAccess) {} }
                var previous = try? FileStamp(url: fileAccess.url)
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    let current = try? FileStamp(url: fileAccess.url)
                    if current != previous {
                        previous = current
                        onChange()
                    }
                }
            }
        }
    }

    deinit {
        fileTask?.cancel()
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    private final class Callback: Sendable {
        let access: FileAccess
        let folder: URL
        let onChange: @Sendable () -> Void

        init(access: FileAccess, folder: URL, onChange: @escaping @Sendable () -> Void) {
            self.access = access
            self.folder = folder.resolvingSymlinksInPath().standardizedFileURL
            self.onChange = onChange
        }
    }
}
