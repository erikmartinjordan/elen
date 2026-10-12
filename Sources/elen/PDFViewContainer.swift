import SwiftUI
import PDFKit
import AppKit

/// Vista transparente encima del PDF que dibuja los sellos, la selección con tiradores
/// en los bordes (para redimensionar) y la huella fantasma.
final class StampsOverlay: NSView {
    enum Handle: CaseIterable {
        case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

        var movesLeft: Bool { self == .topLeft || self == .left || self == .bottomLeft }
        var movesRight: Bool { self == .topRight || self == .right || self == .bottomRight }
        var movesTop: Bool { self == .topLeft || self == .top || self == .topRight }
        var movesBottom: Bool { self == .bottomLeft || self == .bottom || self == .bottomRight }
    }

    weak var pdfView: StampPDFView?
    var placements: [PlacedStamp] = []
    var selectedID: UUID?
    var preview: (image: CGImage, rect: CGRect)?
    var onBoundsChanged: ((UUID, CGRect) -> Void)?

    private(set) var isInteracting = false
    private var resizingHandle: Handle?
    private var resizeStartRect: CGRect = .zero
    private let handleSize: CGFloat = 9
    private let minSize: CGFloat = 18

    override var isFlipped: Bool { false }

    // MARK: - Geometría

    private var selectedStamp: PlacedStamp? {
        guard let id = selectedID else { return nil }
        return placements.first(where: { $0.id == id })
    }

    private var selectedPage: PDFPage? {
        guard let stamp = selectedStamp else { return nil }
        return pdfView?.document?.page(at: stamp.pageIndex)
    }

    private var selectedViewRect: CGRect? {
        guard let pv = pdfView, let page = selectedPage else { return nil }
        return pv.convert(selectedStamp!.pageRect, from: page)
    }

    private func handlePoint(_ handle: Handle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .top: return CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.minY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.minY)
        }
    }

    private func handle(at point: NSPoint) -> Handle? {
        guard let rect = selectedViewRect else { return nil }
        for handle in Handle.allCases {
            let p = handlePoint(handle, in: rect)
            let grip = CGRect(x: p.x - handleSize, y: p.y - handleSize, width: handleSize * 2, height: handleSize * 2)
            if grip.contains(point) { return handle }
        }
        return nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if selectedViewRect != nil, handle(at: point) != nil { return self }
        return nil
    }

    // MARK: - Dibujo

    override func draw(_ dirtyRect: NSRect) {
        guard let pv = pdfView, let doc = pv.document,
              let ctx = NSGraphicsContext.current?.cgContext else { return }

        for stamp in placements {
            guard let page = doc.page(at: stamp.pageIndex) else { continue }
            ctx.draw(stamp.image, in: pv.convert(stamp.pageRect, from: page))
        }

        if let sel = selectedViewRect {
            NSColor.systemBlue.setStroke()
            let outline = NSBezierPath(rect: sel.insetBy(dx: -3, dy: -3))
            outline.lineWidth = 1.5
            outline.setLineDash([6, 3], count: 2, phase: 0)
            outline.stroke()

            for handle in Handle.allCases {
                let p = handlePoint(handle, in: sel)
                let r = CGRect(x: p.x - handleSize / 2, y: p.y - handleSize / 2, width: handleSize, height: handleSize)
                NSColor.white.setFill()
                let path = NSBezierPath(roundedRect: r, xRadius: 2, yRadius: 2)
                path.fill()
                NSColor.systemBlue.setStroke()
                path.lineWidth = 1.5
                path.stroke()
            }
        }

        if let preview {
            ctx.saveGState()
            ctx.setAlpha(0.55)
            ctx.draw(preview.image, in: preview.rect)
            ctx.restoreGState()
            NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
            let path = NSBezierPath(rect: preview.rect.insetBy(dx: -3, dy: -3))
            path.lineWidth = 1
            path.setLineDash([5, 3], count: 2, phase: 0)
            path.stroke()
        }
    }

    // MARK: - Redimensionado desde los bordes

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let rect = selectedViewRect, let handle = handle(at: point) else { return }
        resizingHandle = handle
        resizeStartRect = rect
        isInteracting = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let handle = resizingHandle, let stamp = selectedStamp, let page = selectedPage else { return }
        let point = convert(event.locationInWindow, from: nil)
        let newRect = resizedRect(handle: handle, point: point)
        let pageRect = pdfView?.convert(newRect, to: page) ?? stamp.pageRect
        if let index = placements.firstIndex(where: { $0.id == stamp.id }) {
            placements[index].pageRect = pageRect
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let stamp = selectedStamp, resizingHandle != nil {
            onBoundsChanged?(stamp.id, stamp.pageRect)
        }
        resizingHandle = nil
        isInteracting = false
        needsDisplay = true
    }

    private func resizedRect(handle: Handle, point: CGPoint) -> CGRect {
        var minX = resizeStartRect.minX
        var maxX = resizeStartRect.maxX
        var minY = resizeStartRect.minY
        var maxY = resizeStartRect.maxY

        if handle.movesLeft { minX = min(point.x, maxX - minSize) }
        if handle.movesRight { maxX = max(point.x, minX + minSize) }
        if handle.movesBottom { minY = min(point.y, maxY - minSize) }
        if handle.movesTop { maxY = max(point.y, minY + minSize) }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// PDFView que estampa (clic), selecciona, mueve y redimensiona sellos ya colocados.
final class StampPDFView: PDFView {
    var placementEnabled = false {
        didSet { window?.invalidateCursorRects(for: self) }
    }
    var editingEnabled = false
    var previewImage: CGImage?
    var previewLogicalSize: CGSize = .zero

    var onPlace: ((CGPoint) -> Void)?
    var onSelect: ((UUID?) -> Void)?
    var onMoveCommit: ((UUID, CGRect) -> Void)?
    var onResizeCommit: ((UUID, CGRect) -> Void)?

    private var trackingArea: NSTrackingArea?
    private let overlay = StampsOverlay()
    private var placements: [PlacedStamp] = []
    private var selectedID: UUID?
    private var observedClipView: NSView?

    private struct DragState {
        let id: UUID
        let pageIndex: Int
        let startViewPoint: CGPoint
        let startViewRect: CGRect
    }
    private var dragState: DragState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        commonInit()
    }

    private func commonInit() {
        overlay.pdfView = self
        overlay.frame = bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.onBoundsChanged = { [weak self] id, rect in self?.onResizeCommit?(id, rect) }
        addSubview(overlay)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        bringOverlayToFront()
        setupScrollObservation()
    }

    override var document: PDFDocument? {
        didSet {
            bringOverlayToFront()
            setupScrollObservation()
        }
    }

    override func layout() {
        super.layout()
        overlay.frame = bounds
        overlay.needsDisplay = true
        bringOverlayToFront()
        setupScrollObservation()
    }

    /// El scroll lo gestiona un PDFScrollView interno; observamos su clip para redibujar los sellos.
    private func setupScrollObservation() {
        guard let scrollView = subviews.compactMap({ $0 as? NSScrollView }).first else { return }
        let clip = scrollView.contentView
        guard observedClipView !== clip else { return }
        if let old = observedClipView {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: old)
        }
        observedClipView = clip
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipViewDidScroll),
                                               name: NSView.boundsDidChangeNotification, object: clip)
    }

    @objc private func clipViewDidScroll() {
        overlay.preview = nil
        overlay.needsDisplay = true
    }

    deinit {
        if let clip = observedClipView {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: clip)
        }
    }

    private func bringOverlayToFront() {
        if subviews.last !== overlay {
            addSubview(overlay, positioned: .above, relativeTo: nil)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if placementEnabled { addCursorRect(bounds, cursor: .crosshair) }
    }

    // MARK: - Datos desde SwiftUI

    func update(placements: [PlacedStamp], selected: UUID?) {
        if dragState == nil && !overlay.isInteracting {
            self.placements = placements
            overlay.placements = placements
        }
        self.selectedID = selected
        overlay.selectedID = selected
        overlay.needsDisplay = true
    }

    func configurePreview(image: CGImage?, logicalSize: CGSize) {
        previewImage = image
        previewLogicalSize = logicalSize
        if image == nil { clearPreview() }
    }

    // MARK: - Ratón

    override func mouseMoved(with event: NSEvent) {
        updatePreview(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        clearPreview()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if placementEnabled {
            onPlace?(point)
            return
        }
        guard editingEnabled else {
            super.mouseDown(with: event)
            return
        }
        if let hit = hitTestStamp(point), let page = document?.page(at: hit.pageIndex) {
            onSelect?(hit.id)
            dragState = DragState(id: hit.id, pageIndex: hit.pageIndex,
                                  startViewPoint: point,
                                  startViewRect: convert(hit.pageRect, from: page))
        } else {
            onSelect?(nil)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let state = dragState, let page = document?.page(at: state.pageIndex) else {
            super.mouseDragged(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - state.startViewPoint.x
        let dy = point.y - state.startViewPoint.y
        let newViewRect = state.startViewRect.offsetBy(dx: dx, dy: dy)
        let newPageRect = convert(newViewRect, to: page)
        if let index = placements.firstIndex(where: { $0.id == state.id }) {
            placements[index].pageRect = newPageRect
            overlay.placements = placements
            overlay.needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        let state = dragState
        dragState = nil
        if let state, let placed = placements.first(where: { $0.id == state.id }) {
            onMoveCommit?(state.id, placed.pageRect)
        }
        super.mouseUp(with: event)
    }

    // MARK: - Ayudas

    private func hitTestStamp(_ viewPoint: CGPoint) -> PlacedStamp? {
        guard let doc = document else { return nil }
        for stamp in placements.reversed() {
            guard let page = doc.page(at: stamp.pageIndex) else { continue }
            if convert(stamp.pageRect, from: page).insetBy(dx: -4, dy: -4).contains(viewPoint) {
                return stamp
            }
        }
        return nil
    }

    private func clearPreview() {
        overlay.preview = nil
        overlay.needsDisplay = true
    }

    private func updatePreview(at viewPoint: CGPoint) {
        guard placementEnabled,
              let image = previewImage,
              previewLogicalSize.width > 1,
              let page = page(for: viewPoint, nearest: false) else {
            clearPreview()
            return
        }
        let pagePoint = convert(viewPoint, to: page)
        let pageBounds = page.bounds(for: displayBox)
        let w = previewLogicalSize.width
        let h = previewLogicalSize.height
        let cx = min(max(pagePoint.x, pageBounds.minX + w / 2), pageBounds.maxX - w / 2)
        let cy = min(max(pagePoint.y, pageBounds.minY + h / 2), pageBounds.maxY - h / 2)

        let center = convert(CGPoint(x: cx, y: cy), from: page)
        let scale = scaleFactor
        let rect = CGRect(x: center.x - w * scale / 2, y: center.y - h * scale / 2,
                          width: w * scale, height: h * scale)
        overlay.preview = (image, rect)
        overlay.needsDisplay = true
    }
}

struct PDFViewContainer: NSViewRepresentable {
    let document: PDFDocument?
    let placements: [PlacedStamp]
    let selectedID: UUID?
    let placementEnabled: Bool
    let editingEnabled: Bool
    let previewImage: CGImage?
    let previewLogicalSize: CGSize
    let onPlace: (CGPoint) -> Void
    let onSelect: (UUID?) -> Void
    let onMoveCommit: (UUID, CGRect) -> Void
    let onResizeCommit: (UUID, CGRect) -> Void
    let onCreated: (PDFView) -> Void

    func makeNSView(context: Context) -> StampPDFView {
        let view = StampPDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = .clear
        apply(to: view)
        onCreated(view)
        return view
    }

    func updateNSView(_ nsView: StampPDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
            if document != nil { nsView.autoScales = true }
        }
        nsView.backgroundColor = .clear
        nsView.pageShadowsEnabled = true
        apply(to: nsView)
        onCreated(nsView)
    }

    private func apply(to view: StampPDFView) {
        view.onPlace = onPlace
        view.onSelect = onSelect
        view.onMoveCommit = onMoveCommit
        view.onResizeCommit = onResizeCommit
        view.placementEnabled = placementEnabled
        view.editingEnabled = editingEnabled
        view.configurePreview(image: previewImage, logicalSize: previewLogicalSize)
        view.update(placements: placements, selected: selectedID)
    }
}
