import Foundation
import Testing

@testable import LuloCore

/// Ensures the enclosing folder stops at the filesystem root instead of wrapping to itself.
@Test
func parentOfFolderStopsAtRoot() {
    #expect(
        FolderNavigation.parent(of: URL(fileURLWithPath: "/photos/albums/trip"))
            == URL(fileURLWithPath: "/photos/albums"))
    #expect(FolderNavigation.parent(of: URL(fileURLWithPath: "/photos")) == URL(fileURLWithPath: "/"))
    #expect(FolderNavigation.parent(of: URL(fileURLWithPath: "/")) == nil)
}

/// Ensures browsing stays inside the authorized tree and rejects similarly prefixed siblings.
@Test
func authorizedFolderContainsDescendantsOnly() {
    let root = URL(fileURLWithPath: "/photos")
    #expect(FolderNavigation.contains(root, in: root))
    #expect(FolderNavigation.contains(URL(fileURLWithPath: "/photos/trip"), in: root))
    #expect(!FolderNavigation.contains(URL(fileURLWithPath: "/photographs"), in: root))
    #expect(!FolderNavigation.contains(URL(fileURLWithPath: "/"), in: root))
    #expect(FolderNavigation.contains(URL(fileURLWithPath: "/photos"), in: URL(fileURLWithPath: "/")))
}
