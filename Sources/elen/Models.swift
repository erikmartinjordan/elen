import Foundation
import PDFKit
import AppKit

/// Un sello ya colocado por el usuario: página, rectángulo (coordenadas de página, y hacia arriba) e imagen a estampar.
struct PlacedStamp: Identifiable {
    let id: UUID
    let kind: StampKind
    let image: CGImage
    var pageIndex: Int
    var pageRect: CGRect
}

/// Una firma guardada en la biblioteca del usuario.
struct StoredSignature: Identifiable, Equatable {
    let id: URL
    let image: NSImage

    var url: URL { id }

    static func == (lhs: StoredSignature, rhs: StoredSignature) -> Bool { lhs.id == rhs.id }
}

