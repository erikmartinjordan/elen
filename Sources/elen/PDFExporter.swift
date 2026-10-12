import Foundation
import PDFKit
import CoreGraphics

enum ExportError: LocalizedError {
    case cannotOpen, cannotCreate

    var errorDescription: String? {
        switch self {
        case .cannotOpen: return "No se pudo volver a abrir el PDF original."
        case .cannotCreate: return "No se pudo crear el archivo PDF."
        }
    }
}

enum PDFExporter {
    /// Crea un PDF nuevo: copia el contenido vectorial de cada página y estampa los sellos encima.
    static func export(sourceURL: URL, placements: [PlacedStamp], to url: URL) throws {
        guard let doc = PDFDocument(url: sourceURL) else { throw ExportError.cannotOpen }
        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw ExportError.cannotCreate }
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else { throw ExportError.cannotCreate }

        let rotations = (0..<doc.pageCount).map { doc.page(at: $0)?.rotation ?? 0 }

        for i in 0..<doc.pageCount {
            autoreleasepool {
                guard let page = doc.page(at: i), let cg = page.pageRef else { return }
                let media = cg.getBoxRect(.mediaBox)
                let boxData = withUnsafeBytes(of: media) { CFDataCreate(nil, $0.baseAddress, $0.count) }
                let info: [CFString: Any] = [kCGPDFContextMediaBox: boxData as Any]
                ctx.beginPDFPage(info as CFDictionary)
                ctx.saveGState()
                ctx.translateBy(x: -media.origin.x, y: -media.origin.y)
                ctx.drawPDFPage(cg)
                ctx.restoreGState()
                for stamp in placements where stamp.pageIndex == i {
                    ctx.draw(stamp.image, in: stamp.pageRect)
                }
                ctx.endPDFPage()
            }
        }
        ctx.closePDF()

        // Preservar la rotación de cada página (los sellos ya están en coordenadas sin rotar).
        if rotations.contains(where: { $0 != 0 }), let outDoc = PDFDocument(url: url) {
            for i in 0..<min(rotations.count, outDoc.pageCount) {
                outDoc.page(at: i)?.rotation = rotations[i]
            }
            outDoc.write(to: url)
        }
    }
}
