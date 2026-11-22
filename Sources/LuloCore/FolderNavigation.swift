import Foundation

/// Keeps browsing inside the folder tree that the user authorized.
public enum FolderNavigation {
    /// Returns the enclosing folder, or nil when `folder` is a filesystem root.
    public static func parent(of folder: URL) -> URL? {
        let normalized = folder.standardizedFileURL
        let parent = normalized.deletingLastPathComponent().standardizedFileURL
        guard parent.path != normalized.path else { return nil }
        // Removing the trailing slash keeps equality with URLs built from folder components.
        return URL(fileURLWithPath: parent.path)
    }

    /// Checks a folder or one of its descendants. Resolving links prevents a path such as
    /// `/private/var/...` from failing to match the `/var/...` URL that a panel returns.
    public static func contains(_ folder: URL, in root: URL) -> Bool {
        let folderPath = folder.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        if folderPath == rootPath { return true }
        if rootPath == "/" { return folderPath.hasPrefix("/") }
        return folderPath.hasPrefix(rootPath + "/")
    }
}
