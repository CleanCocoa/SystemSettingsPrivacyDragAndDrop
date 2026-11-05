import Foundation

/// A Privacy & Security list in System Settings that accepts an app dropped onto it.
///
/// Lists that only hold apps which already asked (Microphone, Camera) take no drops,
/// so they are not representable here.
public enum PrivacyPane: Sendable, CaseIterable {
    case accessibility
    case inputMonitoring
    case screenRecording
    case systemAudioRecording
    case fullDiskAccess

    public var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)")!
    }

    /// The list's title as System Settings shows it on the running OS.
    public var listName: String {
        switch self {
        case .accessibility:
            ProcessInfo.processInfo.isOperatingSystemAtLeast(.init(majorVersion: 27, minorVersion: 0, patchVersion: 0))
                ? "Device Control and Data Access"
                : "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .screenRecording: "Screen & System Audio Recording"
        case .systemAudioRecording: "System Audio Recording Only"
        case .fullDiskAccess: "Full Disk Access"
        }
    }

    private var anchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        case .screenRecording: "Privacy_ScreenCapture"
        case .systemAudioRecording: "Privacy_AudioCapture"
        case .fullDiskAccess: "Privacy_AllFiles"
        }
    }
}
