import AppKit

/// The System Settings app, as seen from outside through the window server.
@MainActor
public enum SystemSettings {
    static let bundleIdentifier = "com.apple.systempreferences"

    /// Frame of the main System Settings window in AppKit screen coordinates, if one is on screen.
    ///
    /// Reads only window bounds and owner, which needs no Screen Recording permission.
    public static func mainWindowFrame() -> NSRect? {
        guard let pid = runningApp?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[CFString: Any]]
        else { return nil }

        let frames = windows.compactMap { window -> CGRect? in
            guard (window[kCGWindowOwnerPID] as? pid_t) == pid,
                  (window[kCGWindowLayer] as? Int) == 0,
                  let bounds = window[kCGWindowBounds] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds),
                  frame.width >= 300, frame.height >= 200
            else { return nil }
            return frame
        }
        return frames.max { $0.width * $0.height < $1.width * $1.height }.map(appKitFrame)
    }

    /// Opens `pane`. A System Settings launched cold restores its last pane instead of the
    /// requested one, so then the URL is sent again once its window is up.
    static func open(_ pane: PrivacyPane) -> Task<Void, Never>? {
        let wasRunning = runningApp != nil
        NSWorkspace.shared.open(pane.settingsURL)
        guard !wasRunning else { return nil }
        return Task {
            for _ in 0..<100 where mainWindowFrame() == nil {
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

    /// Quartz window bounds have a top-left origin on the primary screen; AppKit's is bottom-left.
    private static func appKitFrame(_ frame: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return frame }
        return NSRect(x: frame.minX, y: primary.frame.height - frame.maxY, width: frame.width, height: frame.height)
    }
}
