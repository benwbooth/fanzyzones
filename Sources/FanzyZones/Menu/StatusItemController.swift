import AppKit

/// Owns the menu-bar status item and its dropdown.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let state: AppState
    private let snapEngine: SnapEngine
    private let accessibility: AccessibilityGate
    /// Open the editor. nil = create a new layout; non-nil = edit/duplicate it.
    private let onEditLayout: (Layout?) -> Void
    private let onOpenSettings: () -> Void
    private let onShowAbout: () -> Void
    /// Which display the menu currently assigns layouts to (multi-display only).
    private var targetDisplayUUID: String?

    init(state: AppState,
         snapEngine: SnapEngine,
         accessibility: AccessibilityGate,
         onEditLayout: @escaping (Layout?) -> Void,
         onOpenSettings: @escaping () -> Void,
         onShowAbout: @escaping () -> Void) {
        self.state = state
        self.snapEngine = snapEngine
        self.accessibility = accessibility
        self.onEditLayout = onEditLayout
        self.onOpenSettings = onOpenSettings
        self.onShowAbout = onShowAbout
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "rectangle.3.group",
                                   accessibilityDescription: "FanzyZones") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "FZ"
            }
        }

        rebuildMenu()
    }

    /// Rebuilds the dropdown from current state, reusing the existing menu object.
    func rebuildMenu() {
        let menu: NSMenu
        if let existing = statusItem.menu {
            menu = existing
        } else {
            menu = NSMenu()
            menu.delegate = self
            statusItem.menu = menu
        }
        populate(menu)
    }

    /// Fills `menu` with the current items. Mutates the passed-in menu in place so
    /// that rebuilding from `menuNeedsUpdate(_:)` updates the menu that is actually
    /// about to open (replacing `statusItem.menu` there leaves the open menu stale,
    /// which made selections appear to need a second click).
    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        addHeader(to: menu)
        addAccessibilitySection(to: menu)
        menu.addItem(.separator())
        addLayoutsSection(to: menu)
        menu.addItem(.separator())
        addSnapModeSection(to: menu)

        let create = NSMenuItem(title: "Create Custom Layout…",
                                action: #selector(createCustomLayout),
                                keyEquivalent: "")
        create.target = self
        menu.addItem(create)

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let reveal = NSMenuItem(title: "Reveal Config in Finder",
                                action: #selector(revealConfig), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)

        menu.addItem(.separator())
        let about = NSMenuItem(title: "About FanzyZones",
                               action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit FanzyZones",
                              action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Menu sections

    private func addHeader(to menu: NSMenu) {
        let title = NSMenuItem(title: "FanzyZones", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
    }

    private func addAccessibilitySection(to menu: NSMenu) {
        let trusted = accessibility.isTrusted
        let status = NSMenuItem(
            title: trusted ? "Accessibility: Granted" : "Accessibility: Not granted",
            action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if !trusted {
            let grant = NSMenuItem(title: "Grant Accessibility…",
                                   action: #selector(grantAccessibility), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        }
    }

    private func addLayoutsSection(to menu: NSMenu) {
        let header = NSMenuItem(title: "Layouts — click a pane to snap, name to set active",
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let displays = DisplayManager.displays()
        // Resolve the display the menu is assigning to (default: main).
        if targetDisplayUUID == nil || !displays.contains(where: { $0.uuid == targetDisplayUUID }) {
            targetDisplayUUID = DisplayManager.mainUUID()
        }
        let target = targetDisplayUUID

        // Only show the display picker when there's more than one screen.
        if displays.count > 1 {
            let pickHeader = NSMenuItem(title: "Set layout for display:", action: nil,
                                        keyEquivalent: "")
            pickHeader.isEnabled = false
            menu.addItem(pickHeader)
            for display in displays {
                let item = NSMenuItem(title: "  \(display.name)",
                                      action: #selector(selectTargetDisplay(_:)),
                                      keyEquivalent: "")
                item.target = self
                item.state = display.uuid == target ? .on : .off
                item.representedObject = display.uuid
                menu.addItem(item)
            }
        }

        let activeId = state.layoutId(forDisplayUUID: target)
        // Show the active layout first, keeping the rest in their normal order.
        var orderedLayouts = state.allLayouts
        if let activeIdx = orderedLayouts.firstIndex(where: { $0.id == activeId }) {
            orderedLayouts.insert(orderedLayouts.remove(at: activeIdx), at: 0)
        }
        for layout in orderedLayouts {
            let item = NSMenuItem()
            item.view = LayoutMenuItemView(
                layout: layout,
                isActive: layout.id == activeId,
                onSnap: { [weak self] layoutId, zoneId in
                    self?.snap(layoutId: layoutId, zoneId: zoneId)
                },
                onSetActive: { [weak self] layoutId in
                    guard let self, let target = self.targetDisplayUUID else { return }
                    self.state.setLayout(layoutId, forDisplayUUID: target)
                },
                onEdit: layout.isBuiltIn ? nil : { [weak self] in
                    self?.onEditLayout(layout)
                },
                onDelete: layout.isBuiltIn ? nil : { [weak self] in
                    self?.state.deleteCustomLayout(id: layout.id)
                })
            menu.addItem(item)
        }
    }

    @objc private func selectTargetDisplay(_ sender: NSMenuItem) {
        targetDisplayUUID = sender.representedObject as? String
        rebuildMenu()
    }

    private func addSnapModeSection(to menu: NSMenu) {
        let header = NSMenuItem(title: "Snap Mode", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let mods = state.settings.modifiers
            .map(\.displayName).sorted().joined(separator: "+")
        let modName = mods.isEmpty ? "Modifier" : mods

        let modifier = NSMenuItem(title: "Hold \(modName) and drag",
                                  action: #selector(setModeModifier), keyEquivalent: "")
        modifier.target = self
        modifier.state = state.settings.snapMode == .modifier ? .on : .off
        menu.addItem(modifier)

        let auto = NSMenuItem(title: "Auto-snap on any drag",
                              action: #selector(setModeAuto), keyEquivalent: "")
        auto.target = self
        auto.state = state.settings.snapMode == .auto ? .on : .off
        menu.addItem(auto)
    }

    // MARK: - Actions

    @objc private func grantAccessibility() {
        if !accessibility.promptIfNeeded() { accessibility.openSettingsPane() }
    }

    /// Snap the focused window into a layout's pane (invoked by the visual menu view).
    private func snap(layoutId: String, zoneId: Int) {
        guard accessibility.isTrusted else { grantAccessibility(); return }
        guard let layout = state.layout(withId: layoutId),
              let zone = layout.zones.first(where: { $0.id == zoneId }),
              let screen = screenForFocusedWindow() else {
            NSSound.beep()
            return
        }
        snapEngine.snapFocusedWindow(to: zone, on: screen)
    }

    @objc private func setModeModifier() { state.setSnapMode(.modifier) }
    @objc private func setModeAuto() { state.setSnapMode(.auto) }

    @objc private func createCustomLayout() { onEditLayout(nil) }

    @objc private func openSettings() { onOpenSettings() }

    @objc private func revealConfig() {
        let dir = Persistence.directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc private func showAbout() { onShowAbout() }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Helpers

    /// Screen the frontmost window currently sits on, falling back to the main screen.
    private func screenForFocusedWindow() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        populate(menu)
    }
}
