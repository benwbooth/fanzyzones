import SwiftUI

/// Settings UI. Edits a local copy of `AppSettings` and reports every change back via
/// `onChange` so the live engine and persistence update immediately.
struct SettingsView: View {
    @State private var settings: AppSettings
    @State private var launchAtLogin: Bool
    @State private var accessibilityTrusted: Bool
    @State private var showResetConfirm = false

    private let onChange: (AppSettings) -> Void
    private let onGrantAccessibility: () -> Void
    private let refreshTrust: () -> Bool

    init(settings: AppSettings,
         onChange: @escaping (AppSettings) -> Void,
         onGrantAccessibility: @escaping () -> Void,
         refreshTrust: @escaping () -> Bool) {
        _settings = State(initialValue: settings)
        _launchAtLogin = State(initialValue: LaunchAtLogin.isEnabled)
        _accessibilityTrusted = State(initialValue: refreshTrust())
        self.onChange = onChange
        self.onGrantAccessibility = onGrantAccessibility
        self.refreshTrust = refreshTrust
    }

    var body: some View {
        Form {
            Section("Snapping") {
                Picker("Mode", selection: $settings.snapMode) {
                    Text("Hold modifier and drag").tag(SnapMode.modifier)
                    Text("Auto-snap on any drag").tag(SnapMode.auto)
                }
                .pickerStyle(.radioGroup)

                if settings.snapMode == .modifier {
                    HStack {
                        Text("Modifier keys")
                        Spacer()
                        ForEach(ModifierKey.allCases, id: \.self) { key in
                            Toggle(key.displayName, isOn: binding(for: key))
                                .toggleStyle(.button)
                        }
                    }
                    if settings.modifiers.isEmpty {
                        Text("Pick at least one modifier, or snapping can't engage.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }

            Section("Zones") {
                sliderRow("Gap between zones", value: $settings.gap, range: 0...40, unit: "pt")
                sliderRow("Outer padding", value: $settings.padding, range: 0...40, unit: "pt")
            }

            Section("Overlay Appearance") {
                ColorPicker("Highlight color", selection: highlightBinding, supportsOpacity: false)
                sliderRow("Opacity", value: opacityBinding, range: 0.1...0.8, unit: "%",
                          display: { Int($0 * 100) })
                Toggle("Show zone numbers", isOn: $settings.showZoneNumbers)
            }

            Section("Keyboard Shortcuts") {
                Toggle("Enable snapping shortcuts", isOn: $settings.keyboardShortcutsEnabled)
                if settings.keyboardShortcutsEnabled {
                    LabeledContent("Previous / next zone", value: "⌃⌥← / ⌃⌥→")
                    LabeledContent("Snap to zone 1–9", value: "⌃⌥1 … ⌃⌥9")
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in LaunchAtLogin.set(on) }

                HStack {
                    Text("Accessibility")
                    Spacer()
                    if accessibilityTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Grant…") {
                            onGrantAccessibility()
                            accessibilityTrusted = refreshTrust()
                        }
                    }
                }

                Button("Reset Settings to Defaults…", role: .destructive) {
                    showResetConfirm = true
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 680)
        .onChange(of: settings) { _, new in onChange(new) }
        .confirmationDialog("Reset all settings to their defaults?",
                            isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                // Preserve the active layout; reset only the tunable settings.
                var defaults = AppSettings()
                defaults.activeLayoutId = settings.activeLayoutId
                settings = defaults
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Snap mode, modifier keys, gap, and padding return to defaults. "
                 + "Your custom layouts are not affected.")
        }
    }

    private func sliderRow(_ title: String, value: Binding<CGFloat>,
                           range: ClosedRange<CGFloat>, unit: String,
                           display: @escaping (CGFloat) -> Int = { Int($0) }) -> some View {
        let step: CGFloat = (range.upperBound - range.lowerBound) <= 1 ? 0.01 : 1
        return HStack {
            Text(title)
            Slider(value: value, in: range, step: step)
            Text("\(display(value.wrappedValue)) \(unit)")
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var highlightBinding: Binding<Color> {
        Binding(get: { settings.highlightColor.color },
                set: { settings.highlightColor = RGBColor($0) })
    }

    private var opacityBinding: Binding<CGFloat> {
        Binding(get: { CGFloat(settings.overlayOpacity) },
                set: { settings.overlayOpacity = Double($0) })
    }

    private func binding(for key: ModifierKey) -> Binding<Bool> {
        Binding(
            get: { settings.modifiers.contains(key) },
            set: { isOn in
                if isOn { settings.modifiers.insert(key) }
                else { settings.modifiers.remove(key) }
            })
    }
}
