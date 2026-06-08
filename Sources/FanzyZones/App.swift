import AppKit

@main
struct FanzyZonesMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Agent app: no Dock icon, no main menu. Lives in the menu bar.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState!
    private var snapEngine: SnapEngine!
    private let accessibility = AccessibilityGate()
    private let overlay = OverlayController()
    private var dragMonitor: DragMonitor!
    private var editor: EditorWindowController!
    private var settings: SettingsWindowController!
    private var about: AboutWindowController!
    private var hotkeys: HotkeyManager!
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = AppIcon.make()

        let windowManager = WindowManager()
        state = AppState()
        snapEngine = SnapEngine(windowManager: windowManager, state: state)
        dragMonitor = DragMonitor(state: state,
                                  snapEngine: snapEngine,
                                  windowManager: windowManager,
                                  overlay: overlay)
        editor = EditorWindowController(state: state)
        settings = SettingsWindowController(state: state, accessibility: accessibility)
        about = AboutWindowController()

        statusItemController = StatusItemController(
            state: state,
            snapEngine: snapEngine,
            accessibility: accessibility,
            onEditLayout: { [weak self] layout in self?.editor.show(editing: layout) },
            onOpenSettings: { [weak self] in self?.settings.show() },
            onShowAbout: { [weak self] in self?.about.show() }
        )

        hotkeys = HotkeyManager { [weak self] action in
            guard let self else { return }
            switch action {
            case .zone(let index): self.snapEngine.snapFocusedWindow(toZoneIndex: index)
            case .next: self.snapEngine.cycleFocusedWindow(by: 1)
            case .prev: self.snapEngine.cycleFocusedWindow(by: -1)
            }
        }
        applyHotkeySetting()

        // Keep hotkey registration in sync when settings change.
        state.onChange = { [weak self] in self?.applyHotkeySetting() }

        // Rebuild the menu when displays are added/removed/rearranged.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.statusItemController?.rebuildMenu() }
        }

        // Prompt for Accessibility on first launch, then start the drag engine as
        // soon as we're trusted (the event tap needs that permission).
        accessibility.promptIfNeeded()
        accessibility.waitForTrust { [weak self] in
            self?.dragMonitor.start()
        }
    }

    private func applyHotkeySetting() {
        if state.settings.keyboardShortcutsEnabled {
            hotkeys.register()
        } else {
            hotkeys.unregister()
        }
    }
}
