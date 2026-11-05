import AppKit

/// Opens a Privacy & Security list in System Settings and pins a floating panel to the
/// Settings window, offering this app as a tile to drag into the list.
///
/// The panel closes once `isGranted` returns true, or once the Settings window is gone.
@MainActor
public final class PrivacyDragGuide {
    private let bundleURL: URL
    private var openTask: Task<Void, Never>?
    private var tracking: Tracking?

    /// - Precondition: `bundleURL` is an `.app` bundle; System Settings lists nothing else.
    public init(bundleURL: URL = Bundle.main.bundleURL) {
        precondition(bundleURL.pathExtension.lowercased() == "app", "not an app bundle: \(bundleURL.path)")
        self.bundleURL = bundleURL.standardizedFileURL
    }

    public func show(_ pane: PrivacyPane, isGranted: @escaping @MainActor () -> Bool = { false }) {
        close()
        openTask = SystemSettings.open(pane)
        tracking = Tracking(panel: makePanel(for: pane), isGranted: isGranted) { [weak self] in self?.close() }
    }

    public func close() {
        openTask?.cancel()
        openTask = nil
        tracking?.stop()
        tracking = nil
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

/// Keeps one panel pinned to the System Settings window, once per display frame, and
/// hides it while other windows cover all of the Settings window.
@MainActor
private final class Tracking: NSObject {
    private let panel: NSPanel
    private let isGranted: @MainActor () -> Bool
    private let onEnd: @MainActor () -> Void
    private var displayLink: CADisplayLink?
    private var settingsWindowID: CGWindowID?
    private var nextGrantCheck = ContinuousClock.now

    init(panel: NSPanel, isGranted: @escaping @MainActor () -> Bool, onEnd: @escaping @MainActor () -> Void) {
        self.panel = panel
        self.isGranted = isGranted
        self.onEnd = onEnd
        super.init()
        // A screen's display link keeps firing while the panel is ordered out; a view's would not.
        let link = (NSScreen.main ?? NSScreen.screens[0]).displayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        panel.orderOut(nil)
    }

    @objc private func step() {
        let now = ContinuousClock.now
        if now >= nextGrantCheck {
            nextGrantCheck = now + .milliseconds(250)
            if isGranted() { return onEnd() }
        }

        let window = settingsWindowID.flatMap(SystemSettings.window(id:)) ?? SystemSettings.mainWindow()
        guard let window else {
            if settingsWindowID != nil { onEnd() }
            return
        }
        settingsWindowID = window.id
        if SystemSettings.isFullyObscured(window) {
            if panel.isVisible { panel.orderOut(nil) }
        } else {
            pin(to: window.frame)
        }
    }

    private func pin(to settings: NSRect) {
        let size = panel.frame.size
        let visible = NSScreen.screens.first { $0.frame.intersects(settings) }?.visibleFrame ?? settings
        let x = min(max(settings.maxX - size.width - 16, visible.minX + 8), visible.maxX - size.width - 8)
        let y = min(max(settings.minY + 16, visible.minY + 8), visible.maxY - size.height - 8)
        let origin = NSPoint(x: x, y: y)
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}
