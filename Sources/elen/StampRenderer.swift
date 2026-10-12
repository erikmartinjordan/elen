import AppKit
import CoreGraphics

/// Genera las huellas (improntas) que dejan los sellos sobre el papel:
/// la fecha de hoy y la firma, en el color de tinta elegido.
enum StampRenderer {
    static let renderScale: CGFloat = 3
    static let dateBaseSize = CGSize(width: 176, height: 46)
    static let signatureBaseSize = CGSize(width: 188, height: 92)

    static func makeDateImprint(date: Date = Date(), ink: NSColor) -> CGImage? {
        render(logicalSize: dateBaseSize, rotation: 0) { rect in
            drawDate(in: rect, date: date, ink: ink)
        }
    }

    static func makeSignatureImprint(signature: NSImage, ink: NSColor) -> CGImage? {
        render(logicalSize: signatureBaseSize, rotation: -2.2) { rect in
            drawSignature(in: rect, signature: signature, ink: ink)
        }
    }

    // MARK: - Rendering

    private static func render(logicalSize: CGSize, rotation: CGFloat, _ content: (CGRect) -> Void) -> CGImage? {
        let pw = max(1, Int(logicalSize.width * renderScale))
        let ph = max(1, Int(logicalSize.height * renderScale))
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        ctx.scaleBy(x: renderScale, y: renderScale)

        let margin: CGFloat = 8
        let rect = CGRect(x: margin, y: margin,
                          width: logicalSize.width - margin * 2,
                          height: logicalSize.height - margin * 2)

        if rotation != 0 {
            // Ligera inclinación, como un sello real estampado a mano.
            ctx.translateBy(x: logicalSize.width / 2, y: logicalSize.height / 2)
            ctx.rotate(by: rotation * .pi / 180)
            ctx.translateBy(x: -logicalSize.width / 2, y: -logicalSize.height / 2)
        }

        content(rect)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    private static func drawDate(in rect: CGRect, date: Date, ink: NSColor) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd MMM yyyy"
        let text = formatter.string(from: date).uppercased()

        var fontSize = rect.height * 0.86
        var attributed = dateString(text, size: fontSize, ink: ink)
        if attributed.size().width > rect.width {
            fontSize *= rect.width / attributed.size().width
            attributed = dateString(text, size: fontSize, ink: ink)
        }
        let size = attributed.size()
        let r = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                       width: size.width, height: size.height)
        attributed.draw(in: r)
    }

    private static func dateString(_ text: String, size: CGFloat, ink: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold),
            .foregroundColor: ink
        ])
    }

    private static func drawSignature(in rect: CGRect, signature: NSImage, ink: NSColor) {
        let imageSize = signature.size
        guard imageSize.width > 0, imageSize.height > 0,
              let raw = signature.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cg = thresholdAlpha(raw, min: 32) ?? raw

        let ratio = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let w = imageSize.width * ratio
        let h = imageSize.height * ratio
        let target = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)

        ctx.saveGState()
        ctx.clip(to: target, mask: cg)
        ctx.setFillColor(ink.cgColor)
        ctx.fill(target)
        ctx.restoreGState()
    }

    /// Elimina la neblina de píxeles con alfa muy bajo que deja un recuadro fantasma.
    private static func thresholdAlpha(_ cg: CGImage, min minAlpha: UInt8) -> CGImage? {
        let w = cg.width, h = cg.height
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let base = ctx.data else { return nil }
        let bytesPerRow = ctx.bytesPerRow
        let ptr = base.bindMemory(to: UInt8.self, capacity: bytesPerRow * h)
        for y in 0..<h {
            let row = y * bytesPerRow
            for x in 0..<w {
                let alphaIndex = row + x * 4 + 3
                if ptr[alphaIndex] < minAlpha { ptr[alphaIndex] = 0 }
            }
        }
        return ctx.makeImage()
    }
}
