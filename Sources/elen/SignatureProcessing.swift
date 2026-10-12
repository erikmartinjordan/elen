import CoreGraphics
import Foundation

/// Extrae la firma de una foto: convierte los trazos oscuros en tinta negra
/// con fondo transparente y recorta al contenido.
enum SignatureProcessing {
    static func extract(from cgImage: CGImage, threshold: Double = 150) -> CGImage? {
        let maxDim: CGFloat = 1400
        let scale = min(1, maxDim / CGFloat(max(cgImage.width, cgImage.height)))
        let w = max(1, Int(CGFloat(cgImage.width) * scale))
        let h = max(1, Int(CGFloat(cgImage.height) * scale))
        let bytesPerRow = w * 4

        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        guard let base = ctx.data?.bindMemory(to: UInt8.self, capacity: h * bytesPerRow) else { return nil }

        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * bytesPerRow
            for x in 0..<w {
                let i = row + x * 4
                let r = Double(base[i]), g = Double(base[i + 1]), b = Double(base[i + 2])
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                if lum < threshold {
                    let a = min(1.0, (threshold - lum) / threshold * 1.8)
                    base[i] = 0; base[i + 1] = 0; base[i + 2] = 0
                    base[i + 3] = UInt8(max(0, min(255, a * 255)))
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                } else {
                    base[i + 3] = 0
                }
            }
        }

        guard maxX >= minX, maxY >= minY, maxX >= 0, let full = ctx.makeImage() else { return nil }

        let pad = 4
        let cx = max(0, minX - pad)
        let cy = max(0, minY - pad)
        let cw = min(w - cx, (maxX - minX + 1) + pad * 2)
        let ch = min(h - cy, (maxY - minY + 1) + pad * 2)
        guard cw > 0, ch > 0 else { return nil }
        return full.cropping(to: CGRect(x: cx, y: cy, width: cw, height: ch))
    }
}
