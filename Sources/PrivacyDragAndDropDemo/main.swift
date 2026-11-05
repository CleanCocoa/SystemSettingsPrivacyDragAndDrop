import AppKit
import ApplicationServices
import PrivacyDragAndDrop

/// `--probe`: report whether this process is sandboxed and whether it can locate the
/// System Settings window, then exit 0 if found.
@MainActor
func probe() async -> Never {
    let container = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]
    print("sandboxed:", container != nil, container ?? "")
    NSWorkspace.shared.open(PrivacyPane.accessibility.settingsURL)
    for _ in 0..<50 {
        if let window = SystemSettings.mainWindow() {
            print("settings window:", window.id, NSStringFromRect(window.frame))
            exit(0)
        }
        try? await Task.sleep(for: .milliseconds(200))
    }
    print("settings window: not found")
    exit(1)
}

@MainActor
final class DemoController: NSObject, NSApplicationDelegate {
    let guide = PrivacyDragGuide()
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let buttons = PrivacyPane.allCases.map { pane in
            let button = NSButton(title: pane.listName, target: self, action: #selector(showGuide(_:)))
            button.tag = PrivacyPane.allCases.firstIndex(of: pane)!
            return button
        }
        let stack = NSStackView(views: buttons)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Privacy Drag and Drop"
        window.contentView = stack
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate()
    }

    @objc func showGuide(_ sender: NSButton) {
        let pane = PrivacyPane.allCases[sender.tag]
        if pane == .accessibility {
            guide.show(pane, isGranted: { AXIsProcessTrusted() })
        } else {
            guide.show(pane)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

if CommandLine.arguments.contains("--probe") {
    Task { await probe() }
    RunLoop.main.run()
}

let app = NSApplication.shared
let controller = DemoController()
app.delegate = controller
app.setActivationPolicy(.regular)
app.run()
