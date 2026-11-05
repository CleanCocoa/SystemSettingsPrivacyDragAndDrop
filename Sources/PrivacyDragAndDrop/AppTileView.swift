import AppKit

/// The name System Settings lists the app under.
func appDisplayName(_ bundleURL: URL) -> String {
    FileManager.default.displayName(atPath: bundleURL.path)
        .replacingOccurrences(of: ".app", with: "", options: [.anchored, .backwards, .caseInsensitive])
}

/// An icon-and-name tile that drags the app bundle's file URL, as Finder would.
final class AppTileView: NSView, NSDraggingSource {
    let bundleURL: URL
    private let icon: NSImage
    private let name: String
    private var mouseDownEvent: NSEvent?

    init(frame: NSRect, bundleURL: URL) {
        self.bundleURL = bundleURL
        icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        icon.size = NSSize(width: 32, height: 32)
        name = appDisplayName(bundleURL)
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        NSColor.quaternarySystemFill.setFill()
        background.fill()
        NSColor.separatorColor.setStroke()
        background.stroke()

        icon.draw(in: NSRect(x: 10, y: (bounds.height - 32) / 2, width: 32, height: 32))
        (name as NSString).draw(at: NSPoint(x: 52, y: (bounds.height - 16) / 2), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownEvent else { return }
        let dx = event.locationInWindow.x - start.locationInWindow.x
        let dy = event.locationInWindow.y - start.locationInWindow.y
        guard hypot(dx, dy) >= 3 else { return }
        mouseDownEvent = nil

        let item = NSDraggingItem(pasteboardWriter: bundleURL as NSURL)
        item.setDraggingFrame(bounds, contents: snapshot())
        let session = beginDraggingSession(with: [item], event: start, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .none
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    private func snapshot() -> NSImage {
        let image = NSImage(size: bounds.size)
        if let representation = bitmapImageRepForCachingDisplay(in: bounds) {
            cacheDisplay(in: bounds, to: representation)
            image.addRepresentation(representation)
        }
        return image
    }
}
