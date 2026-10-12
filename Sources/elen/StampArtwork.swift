import AppKit

/// Carga los iconos de los sellos (PNG con fondo transparente) si existen.
/// Si no hay archivos, la app dibuja los sellos proceduralmente.
enum StampArtwork {
    private static var cache: [StampKind: NSImage] = [:]
    private static var attempted: Set<StampKind> = []

    static func image(for kind: StampKind) -> NSImage? {
        if attempted.contains(kind) { return cache[kind] }
        attempted.insert(kind)
        let name = kind == .fecha ? "sello-fecha" : "sello-firma"
        let url = SignatureStore.directory.appendingPathComponent("\(name).png")
        if let image = NSImage(contentsOf: url) {
            cache[kind] = image
        }
        return cache[kind]
    }
}
