# PrivacyDragAndDrop

Helps users grant your Mac app a privacy permission. It opens the right Privacy & Security list in System Settings and pins a small panel to the Settings window, showing your app as a tile the user drags into the list. Nobody has to hunt for the "+" button and then for your app in the open dialog.

The panel follows the Settings window as it moves, hides while other windows cover all of it, and closes once the permission is granted or the Settings window closes.

Works in sandboxed apps. It reads only window bounds and owners from the window server, which needs no Screen Recording permission.

Adapted from the permission guide in [hex](https://github.com/anomalyco/hex) (MIT, see `LICENSE-hex`).

## Requirements

- macOS 14 or later.
- Your app runs as an `.app` bundle. System Settings lists nothing else, so `PrivacyDragGuide` traps when initialized with any other URL.

## Installation

Add the package as a Swift Package Manager dependency. While it has no published remote, refer to it by path:

```swift
dependencies: [
    .package(path: "../PrivacyDragAndDrop"),
],
targets: [
    .target(name: "MyApp", dependencies: ["PrivacyDragAndDrop"]),
]
```

In Xcode, use File > Add Package Dependencies… > Add Local….

## Usage

Keep one `PrivacyDragGuide` around, for example on your app delegate or settings controller, so you can call `close()` on it later. The panel ends by itself either way.

```swift
import ApplicationServices
import PrivacyDragAndDrop

@MainActor
final class PermissionsController {
    private let guide = PrivacyDragGuide()

    func grantAccessibility() {
        guide.show(.accessibility, isGranted: { AXIsProcessTrusted() })
    }
}
```

`show(_:isGranted:)` opens the pane and starts the guide. Calling it again replaces the current guide. `close()` removes the panel early.

`isGranted` is polled every 250 ms on the main actor while the guide is open, and the panel closes as soon as it returns `true`. Without it, the panel stays until the user closes System Settings.

### Panes

`PrivacyPane` only has the lists that accept an app dropped onto them:

| Case | System Settings list | A check you can pass as `isGranted` |
|---|---|---|
| `.accessibility` | Accessibility (macOS 27: Device Control and Data Access) | `AXIsProcessTrusted()` |
| `.inputMonitoring` | Input Monitoring | `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted` (import `IOKit.hid`) |
| `.screenRecording` | Screen & System Audio Recording | `CGPreflightScreenCaptureAccess()` |
| `.systemAudioRecording` | System Audio Recording Only | none public; omit `isGranted` |
| `.fullDiskAccess` | Full Disk Access | none public; omit `isGranted` |

Microphone and Camera are missing on purpose: those lists only hold apps that already asked, so the user switches them on instead of dragging. Request those with `AVCaptureDevice.requestAccess(for:)` and, after a refusal, open the pane yourself.

Each case also exposes `settingsURL` for opening the pane without the guide, and `listName` for your own instructions to the user.

### Granting from the user's side

The user drags the tile from the panel into the list in System Settings. macOS may then ask for their password and, for some permissions, ask them to quit and reopen your app. Plan your UI for that relaunch.

## Trying it

`scripts/make-demo-app.sh` builds `build/PrivacyDragAndDropDemo.app`, ad-hoc signed with only the App Sandbox entitlement. Open it and click a pane to see the guide.

To check, without clicking anything, that a sandboxed process finds the Settings window:

```sh
build/PrivacyDragAndDropDemo.app/Contents/MacOS/PrivacyDragAndDropDemo --probe
```

It prints whether it runs sandboxed and the Settings window it found, and exits non-zero if it found none.

Run the tests with `swift test`.
