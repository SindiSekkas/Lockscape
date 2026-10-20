import ServiceManagement

/// The app as a login item, registered through `SMAppService` so it appears in
/// System Settings > General > Login Items.
enum LoginItem {
    private static let service = SMAppService.mainApp

    static var isEnabled: Bool { service.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled { try service.register() } else { try service.unregister() }
    }

    /// Lockscape only works while it is running, so the first launch turns the login item on.
    /// It can be turned off from the menu or in System Settings; that choice is then respected.
    static func enableOnFirstLaunch() {
        guard !Settings.loginItemOffered, !Settings.isIntegrationTest else { return }
        Settings.loginItemOffered = true
        try? service.register()
    }
}
