import SwiftUI

/// A pane being edited, in normalized (0…1, top-left origin) coordinates.
private struct EditZone: Identifiable, Equatable {
    let id = UUID()
    var rect: CGRect
}

/// An in-progress drag of one pane. Held in a single `@State` and rendered from a
/// single source of truth — the gesture itself lives on the fixed canvas, never on
/// the moving pane, which is what keeps dragging smooth and ghost-free.
private struct DragSession {
    let id: UUID
    let isResize: Bool
    let base: CGRect
    var current: CGRect
}

private let kGridDivisions: CGFloat = 24
private let kMinSize: CGFloat = 0.06
private let kHandleHit: CGFloat = 24      // points; corner area that starts a resize

private func pixelsOf(_ rect: CGRect, in size: CGSize) -> CGRect {
    CGRect(x: rect.minX * size.width, y: rect.minY * size.height,
           width: rect.width * size.width, height: rect.height * size.height)
}

private func clampNormalized(_ rect: CGRect) -> CGRect {
    var x = rect.origin.x, y = rect.origin.y
    var w = max(kMinSize, rect.size.width), h = max(kMinSize, rect.size.height)
    x = min(max(0, x), 1 - w)
    y = min(max(0, y), 1 - h)
    w = min(w, 1 - x)
    h = min(h, 1 - y)
    return CGRect(x: x, y: y, width: w, height: h)
}

private func snapNormalized(_ rect: CGRect) -> CGRect {
    func s(_ v: CGFloat) -> CGFloat { (v * kGridDivisions).rounded() / kGridDivisions }
    return clampNormalized(CGRect(x: s(rect.minX), y: s(rect.minY),
                                  width: s(rect.width), height: s(rect.height)))
}

private func movedRect(_ base: CGRect, by t: CGSize, canvas: CGSize) -> CGRect {
    CGRect(x: base.minX + t.width / canvas.width,
           y: base.minY + t.height / canvas.height,
           width: base.width, height: base.height)
}

private func resizedRect(_ base: CGRect, by t: CGSize, canvas: CGSize) -> CGRect {
    CGRect(x: base.minX, y: base.minY,
           width: base.width + t.width / canvas.width,
           height: base.height + t.height / canvas.height)
}

/// Visual editor for building a custom layout.
struct EditorView: View {
    @State private var name: String
    @State private var zones: [EditZone]
    @State private var selectedId: UUID?
    @State private var snapToGrid = true
    @State private var drag: DragSession?

    private let existingId: String?
    private let canvasAspect: CGFloat
    private let onSave: (Layout) -> Void
    private let onCancel: () -> Void

    init(initial: Layout?,
         screenAspect: CGFloat,
         onSave: @escaping (Layout) -> Void,
         onCancel: @escaping (Layout?) -> Void) {
        self.existingId = initial?.isBuiltIn == true ? nil : initial?.id
        self.canvasAspect = screenAspect > 0 ? screenAspect : 1.6
        self.onSave = onSave
        self.onCancel = { onCancel(initial) }
        _name = State(initialValue: {
            guard let initial else { return "My Layout" }
            return initial.isBuiltIn ? "\(initial.name) Copy" : initial.name
        }())
        _zones = State(initialValue: (initial?.zones ?? BuiltInLayouts.twoPanes.zones)
            .map { EditZone(rect: $0.rect) })
    }

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            canvas
            footer
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 560)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            TextField("Layout name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Button { addZone() } label: { Label("Add Pane", systemImage: "plus.square") }

            Button { split(horizontal: false) } label: {
                Label("Split L|R", systemImage: "rectangle.split.2x1")
            }.disabled(selectedId == nil)

            Button { split(horizontal: true) } label: {
                Label("Split T/B", systemImage: "rectangle.split.1x2")
            }.disabled(selectedId == nil)

            Button(role: .destructive) { deleteSelected() } label: {
                Label("Delete", systemImage: "trash")
            }.disabled(selectedId == nil)

            Spacer()
            Toggle("Snap to grid", isOn: $snapToGrid)
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        Color.clear
            .aspectRatio(canvasAspect, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.4)))

                        ForEach(zones) { zone in
                            paneShape(zone, canvas: geo.size)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    // Single gesture on the fixed canvas — it never moves, so there's
                    // no feedback loop with the dragged pane.
                    .gesture(canvasDrag(canvas: geo.size))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The rect to draw for a zone: the live drag rect if it's being dragged.
    private func displayRect(_ zone: EditZone) -> CGRect {
        drag?.id == zone.id ? drag!.current : zone.rect
    }

    /// A non-interactive pane (all input goes to the canvas gesture).
    private func paneShape(_ zone: EditZone, canvas size: CGSize) -> some View {
        let r = pixelsOf(displayRect(zone), in: size)
        let selected = zone.id == selectedId
        let index = (zones.firstIndex { $0.id == zone.id } ?? 0) + 1
        return RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentColor.opacity(selected ? 0.32 : 0.16))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor.opacity(selected ? 0.95 : 0.5),
                              lineWidth: selected ? 2.5 : 1))
            .overlay(Text("\(index)").font(.title3).foregroundStyle(.secondary))
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.accentColor)
                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1.5))
                    .frame(width: 16, height: 16)
                    .padding(3)
            }
            .frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .zIndex(selected ? 1 : 0)
            .allowsHitTesting(false)
    }

    private func canvasDrag(canvas size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if drag == nil {
                    guard let hit = hitTest(value.startLocation, canvas: size) else {
                        selectedId = nil
                        return
                    }
                    selectedId = hit.id
                    let base = zones.first { $0.id == hit.id }!.rect
                    drag = DragSession(id: hit.id, isResize: hit.isResize,
                                       base: base, current: base)
                }
                guard var session = drag else { return }
                session.current = resolve(session, value: value, canvas: size)
                drag = session
            }
            .onEnded { value in
                guard let session = drag else { return }
                update(session.id, rect: resolve(session, value: value, canvas: size))
                drag = nil
            }
    }

    /// Compute a pane's rect from a drag, clamping the cursor to the canvas first so
    /// you can't drag a pane off the workspace, then keeping the rect in bounds.
    private func resolve(_ session: DragSession,
                         value: DragGesture.Value, canvas size: CGSize) -> CGRect {
        // Pin the cursor inside the canvas, then derive translation from it.
        let lx = min(max(0, value.location.x), size.width)
        let ly = min(max(0, value.location.y), size.height)
        let t = CGSize(width: lx - value.startLocation.x, height: ly - value.startLocation.y)
        let raw = session.isResize
            ? resizedRect(session.base, by: t, canvas: size)
            : movedRect(session.base, by: t, canvas: size)
        let clamped = clampNormalized(raw)
        return snapToGrid ? snapNormalized(clamped) : clamped
    }

    /// Find the topmost pane (selected first, then last-drawn) under a point, and
    /// whether the point is in its resize corner.
    private func hitTest(_ point: CGPoint, canvas size: CGSize) -> (id: UUID, isResize: Bool)? {
        let order = zones.sorted {
            ($0.id == selectedId ? 1 : 0) < ($1.id == selectedId ? 1 : 0)
        }
        for zone in order.reversed() {
            let r = pixelsOf(zone.rect, in: size)
            let handle = CGRect(x: r.maxX - kHandleHit, y: r.maxY - kHandleHit,
                                width: kHandleHit, height: kHandleHit)
            if handle.contains(point) { return (zone.id, true) }
            if r.contains(point) { return (zone.id, false) }
        }
        return nil
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(zones.count) pane\(zones.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", role: .cancel) { onCancel() }
                .keyboardShortcut(.cancelAction)
            Button("Save Layout") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(zones.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Mutations

    private func addZone() {
        let z = EditZone(rect: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4))
        zones.append(z)
        selectedId = z.id
    }

    private func deleteSelected() {
        guard let id = selectedId else { return }
        zones.removeAll { $0.id == id }
        selectedId = nil
    }

    private func split(horizontal: Bool) {
        guard let id = selectedId, let idx = zones.firstIndex(where: { $0.id == id }) else {
            return
        }
        let r = zones[idx].rect
        let a: CGRect, b: CGRect
        if horizontal {
            a = CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height / 2)
            b = CGRect(x: r.minX, y: r.midY, width: r.width, height: r.height / 2)
        } else {
            a = CGRect(x: r.minX, y: r.minY, width: r.width / 2, height: r.height)
            b = CGRect(x: r.midX, y: r.minY, width: r.width / 2, height: r.height)
        }
        let first = EditZone(rect: a)
        zones[idx] = first
        zones.insert(EditZone(rect: b), at: idx + 1)
        selectedId = first.id
    }

    private func update(_ id: UUID, rect: CGRect) {
        guard let idx = zones.firstIndex(where: { $0.id == id }) else { return }
        zones[idx].rect = rect
    }

    private func save() {
        let ordered = zones.sorted {
            $0.rect.minY != $1.rect.minY ? $0.rect.minY < $1.rect.minY
                                         : $0.rect.minX < $1.rect.minX
        }
        let outZones = ordered.enumerated().map { i, z in
            Zone(id: i, name: "Zone \(i + 1)", rect: z.rect)
        }
        let id = existingId ?? "custom.\(UUID().uuidString)"
        onSave(Layout(id: id, name: name.trimmingCharacters(in: .whitespaces),
                      zones: outZones, isBuiltIn: false))
    }
}
