import AppKit

/// Opens a Privacy & Security list in System Settings and pins a floating panel to the
/// Settings window, offering this app as a tile to drag into the list.
///
/// The panel closes once `isGranted` returns true, or once the Settings window is gone.
@MainActor
public final class PrivacyDragGuide {
    private let bundleURL: URL
    private var panel: NSPanel?
    private var openTask: Task<Void, Never>?
    private var trackingTask: Task<Void, Never>?

    /// - Precondition: `bundleURL` is an `.app` bundle; System Settings lists nothing else.
    public init(bundleURL: URL = Bundle.main.bundleURL) {
        precondition(bundleURL.pathExtension.lowercased() == "app", "not an app bundle: \(bundleURL.path)")
        self.bundleURL = bundleURL.standardizedFileURL
    }

    public func show(_ pane: PrivacyPane, isGranted: @escaping @MainActor () -> Bool = { false }) {
        close()
        openTask = SystemSettings.open(pane)
        let panel = makePanel(for: pane)
        self.panel = panel
        trackingTask = Task { [weak self] in
            var sawSettingsWindow = false
            while !Task.isCancelled, let self {
                if isGranted() { return self.close() }
                if let settings = SystemSettings.mainWindowFrame() {
                    sawSettingsWindow = true
                    self.pin(panel, to: settings)
                } else if sawSettingsWindow {
                    return self.close()
                }
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    public func close() {
        openTask?.cancel()
        trackingTask?.cancel()
        openTask = nil
        trackingTask = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func pin(_ panel: NSPanel, to settings: NSRect) {
        let size = panel.frame.size
        let visible = NSScreen.screens.first { $0.frame.intersects(settings) }?.visibleFrame ?? settings
        let x = min(max(settings.maxX - size.width - 16, visible.minX + 8), visible.maxX - size.width - 8)
        let y = min(max(settings.minY + 16, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }

    private func makePanel(for pane: PrivacyPane) -> NSPanel {
        let size = NSSize(width: 480, height: 116)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        content.layer?.cornerRadius = 20
        content.layer?.borderWidth = 1
        content.layer?.borderColor = NSColor.separatorColor.cgColor

        let tile = AppTileView(frame: NSRect(x: 18, y: 17, width: size.width - 36, height: 44), bundleURL: bundleURL)
        let instruction = NSTextField(labelWithString: "↑  Drag \(appDisplayName(bundleURL)) into the \(pane.listName) list above")
        instruction.frame = NSRect(x: 18, y: 73, width: size.width - 36, height: 24)
        instruction.font = .systemFont(ofSize: 13, weight: .medium)
        content.addSubview(instruction)
        content.addSubview(tile)
        panel.contentView = content
        return panel
    }
}
