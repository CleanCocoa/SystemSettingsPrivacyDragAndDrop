import AppKit

/// The System Settings app, as seen from outside through the window server.
@MainActor
public enum SystemSettings {
    static let bundleIdentifier = "com.apple.systempreferences"

    /// A System Settings window as the window server reports it.
    public struct Window: Equatable, Sendable {
        public let id: CGWindowID
        /// In AppKit screen coordinates.
        public let frame: NSRect
    }

    /// The largest on-screen System Settings window, if any.
    ///
    /// Reads only window bounds and owner, which needs no Screen Recording permission.
    public static func mainWindow() -> Window? {
        guard let pid = runningApp?.processIdentifier else { return nil }
        return windows(CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID))
            .filter { $0.pid == pid && $0.frame.width >= 300 && $0.frame.height >= 200 }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            .map(\.window)
    }

    /// The window `id` while it is still on screen; cheap enough to call every frame.
    static func window(id: CGWindowID) -> Window? {
        windows(CGWindowListCopyWindowInfo(.optionIncludingWindow, id))
            .first { $0.window.id == id && $0.isOnScreen }?
            .window
    }

    /// Whether ordinary app windows stacked above `window` hide all of it.
    static func isFullyObscured(_ window: Window) -> Bool {
        let above = windows(CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow, window.id))
        return isFullyCovered(window.frame, by: above.map(\.frame))
    }

    /// Opens `pane`. A System Settings launched cold restores its last pane instead of the
    /// requested one, so then the URL is sent again once its window is up.
    static func open(_ pane: PrivacyPane) -> Task<Void, Never>? {
        let wasRunning = runningApp != nil
        NSWorkspace.shared.open(pane.settingsURL)
        guard !wasRunning else { return nil }
        return Task {
            for _ in 0..<100 where mainWindow() == nil {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
            }
            for delay in [350, 850] {
                try? await Task.sleep(for: .milliseconds(delay))
                if Task.isCancelled { return }
                NSWorkspace.shared.open(pane.settingsURL)
            }
        }
    }

    private static var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }

    private struct WindowInfo {
        let window: Window
        let pid: pid_t
        let isOnScreen: Bool
        var frame: NSRect { window.frame }
    }

    private static func windows(_ list: CFArray?) -> [WindowInfo] {
        (list as? [[CFString: Any]] ?? []).compactMap { info in
            guard let id = info[kCGWindowNumber] as? CGWindowID,
                  let pid = info[kCGWindowOwnerPID] as? pid_t,
                  (info[kCGWindowLayer] as? Int) == 0,
                  let bounds = info[kCGWindowBounds] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds)
            else { return nil }
            return WindowInfo(window: Window(id: id, frame: appKitFrame(frame)),
                              pid: pid,
                              isOnScreen: info[kCGWindowIsOnscreen] as? Bool ?? false)
        }
    }

    /// Quartz window bounds have a top-left origin on the primary screen; AppKit's is bottom-left.
    private static func appKitFrame(_ frame: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return frame }
        return NSRect(x: frame.minX, y: primary.frame.height - frame.maxY, width: frame.width, height: frame.height)
    }
}
