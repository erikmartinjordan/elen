import SwiftUI
import AppKit

/// Controla los trazos dibujados y produce una imagen con fondo transparente.
final class DrawingController: ObservableObject {
    @Published private(set) var isEmpty = true
    fileprivate var strokes: [[CGPoint]] = []
    fileprivate weak var view: DrawingCanvasView?

    func clear() {
        strokes.removeAll()
        isEmpty = true
        view?.needsDisplay = true
    }

    func undo() {
        if !strokes.isEmpty { strokes.removeLast() }
        isEmpty = strokes.isEmpty
        view?.needsDisplay = true
    }

    fileprivate func addStroke(_ stroke: [CGPoint]) {
        strokes.append(stroke)
        isEmpty = false
        view?.needsDisplay = true
    }

    func currentImage() -> NSImage? {
        guard !strokes.isEmpty else { return nil }
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for stroke in strokes {
            for p in stroke {
                minX = min(minX, p.x); minY = min(minY, p.y)
                maxX = max(maxX, p.x); maxY = max(maxY, p.y)
            }
        }
        let pad: CGFloat = 8
        minX -= pad; minY -= pad; maxX += pad; maxY += pad
        let w = maxX - minX, h = maxY - minY
        guard w > 1, h > 1 else { return nil }

        let scale: CGFloat = 3
        let pw = Int(w * scale), ph = Int(h * scale)
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -minX, y: -minY)
        ctx.setStrokeColor(CGColor(gray: 0.05, alpha: 1))
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for stroke in strokes {
            guard let first = stroke.first else { continue }
            ctx.beginPath()
            ctx.move(to: first)
            for p in stroke.dropFirst() { ctx.addLine(to: p) }
            if stroke.count == 1 { ctx.addLine(to: CGPoint(x: first.x + 0.1, y: first.y)) }
            ctx.strokePath()
        }
        guard let cg = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: w, height: h))
    }
}

final class DrawingCanvasView: NSView {
    weak var controller: DrawingController?
    private var current: [CGPoint] = []

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        NSColor(calibratedWhite: 0.85, alpha: 1).setStroke()
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        border.stroke()

        NSColor(calibratedWhite: 0.9, alpha: 1).setStroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: 24, y: 60))
        base.line(to: NSPoint(x: bounds.width - 24, y: 60))
        base.lineWidth = 1
        base.stroke()

        NSColor(calibratedWhite: 0.05, alpha: 1).setStroke()
        if let controller {
            for stroke in controller.strokes { drawStroke(stroke) }
        }
        drawStroke(current)
    }

    private func drawStroke(_ stroke: [CGPoint]) {
        guard let first = stroke.first else { return }
        let path = NSBezierPath()
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: first)
        for p in stroke.dropFirst() { path.line(to: p) }
        if stroke.count == 1 { path.line(to: NSPoint(x: first.x + 0.1, y: first.y)) }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        current = [convert(event.locationInWindow, from: nil)]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current.append(convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if !current.isEmpty { controller?.addStroke(current) }
        current = []
        needsDisplay = true
    }
}

struct SignatureCanvas: NSViewRepresentable {
    @ObservedObject var controller: DrawingController

    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.controller = controller
        controller.view = view
        return view
    }

    func updateNSView(_ nsView: DrawingCanvasView, context: Context) {
        nsView.controller = controller
        controller.view = nsView
    }
}
