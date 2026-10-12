import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var documentURL: URL?
    @Published var document: PDFDocument?
    @Published var signature: NSImage?
    @Published var signatures: [StoredSignature] = []
    @Published var selectedSignatureID: URL?
    @Published var dateImprint: NSImage?
    @Published var signatureImprint: NSImage?
    @Published var placements: [PlacedStamp] = []
    @Published var selectedID: UUID?
    @Published var inkColor: NSColor
    @Published var stampScale: CGFloat
    @Published var showSignatureEditor = false

    private var dateStampImage: CGImage?
    private var signatureStampImage: CGImage?

    weak var pdfView: PDFView?

    var placementCount: Int { placements.count }
    var hasSelection: Bool { selectedID != nil }

    var documentName: String {
        documentURL?.deletingPathExtension().lastPathComponent.uppercased() ?? ""
    }

    init() {
        let d = UserDefaults.standard
        let version = d.integer(forKey: "settingsVersion")
        if version >= 2 {
            let r = d.object(forKey: "inkR") as? Double ?? 0
            let g = d.object(forKey: "inkG") as? Double ?? 0
            let b = d.object(forKey: "inkB") as? Double ?? 0
            inkColor = NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
            stampScale = CGFloat(d.object(forKey: "stampScale") as? Double ?? 1.0)
        } else {
            // Por omisión, tinta negra.
            inkColor = .black
            stampScale = 1.0
        }
        d.set(2, forKey: "settingsVersion")
        let c = inkColor.usingColorSpace(.sRGB) ?? inkColor
        d.set(Double(c.redComponent), forKey: "inkR")
        d.set(Double(c.greenComponent), forKey: "inkG")
        d.set(Double(c.blueComponent), forKey: "inkB")
        d.set(Double(stampScale), forKey: "stampScale")
    }

    // MARK: - Tamaños

    static func baseSize(for kind: StampKind) -> CGSize {
        kind == .fecha ? StampRenderer.dateBaseSize : StampRenderer.signatureBaseSize
    }

    func baseSize(for kind: StampKind) -> CGSize { Self.baseSize(for: kind) }

    /// Tamaño lógico base (sin escalar) para el sello seleccionado o por defecto.
    func stampImage(for kind: StampKind) -> CGImage? {
        kind == .fecha ? dateStampImage : signatureStampImage
    }

    func imprint(for kind: StampKind) -> NSImage? {
        kind == .fecha ? dateImprint : signatureImprint
    }

    /// Escala actual del sello colocado seleccionado (o la escala por defecto).
    var effectiveScale: CGFloat {
        if let id = selectedID, let p = placements.first(where: { $0.id == id }) {
            let base = Self.baseSize(for: p.kind)
            return base.width > 0 ? p.pageRect.width / base.width : 1
        }
        return stampScale
    }

    func logicalSize(for kind: StampKind) -> CGSize {
        let s = Self.baseSize(for: kind)
        return CGSize(width: s.width * stampScale, height: s.height * stampScale)
    }

    // MARK: - Ajustes

    func setInk(_ color: NSColor) {
        inkColor = color
        savePrefs()
        rebuildImprints()
    }

    func setScale(_ value: CGFloat) {
        let clamped = min(max(value, 0.5), 2.0)
        if let id = selectedID, let index = placements.firstIndex(where: { $0.id == id }) {
            let p = placements[index]
            let base = Self.baseSize(for: p.kind)
            let size = CGSize(width: base.width * clamped, height: base.height * clamped)
            let center = CGPoint(x: p.pageRect.midX, y: p.pageRect.midY)
            placements[index].pageRect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                                                width: size.width, height: size.height)
        } else {
            stampScale = clamped
            savePrefs()
            rebuildImprints()
        }
    }

    private func savePrefs() {
        let d = UserDefaults.standard
        let c = inkColor.usingColorSpace(.sRGB) ?? inkColor
        d.set(Double(c.redComponent), forKey: "inkR")
        d.set(Double(c.greenComponent), forKey: "inkG")
        d.set(Double(c.blueComponent), forKey: "inkB")
        d.set(Double(stampScale), forKey: "stampScale")
    }

    // MARK: - Ciclo

    func loadSignatureIfNeeded() {
        signatures = SignatureStore.loadAll()
        let saved = SignatureStore.selectedURL
        let chosen = signatures.first(where: { $0.id == saved }) ?? signatures.last
        selectedSignatureID = chosen?.id
        signature = chosen?.image
        rebuildImprints()
    }

    func selectSignature(_ stored: StoredSignature) {
        selectedSignatureID = stored.id
        signature = stored.image
        SignatureStore.selectedURL = stored.id
        rebuildImprints()
    }

    func addSignature(_ image: NSImage) {
        guard let stored = SignatureStore.add(image) else { return }
        signatures.append(stored)
        selectSignature(stored)
    }

    func deleteSignature(_ stored: StoredSignature) {
        SignatureStore.delete(stored)
        signatures.removeAll { $0.id == stored.id }
        guard selectedSignatureID == stored.id else { return }
        let next = signatures.last
        selectedSignatureID = next?.id
        signature = next?.image
        SignatureStore.selectedURL = next?.id
        rebuildImprints()
    }

    func rebuildImprints() {
        if let cg = StampRenderer.makeDateImprint(ink: inkColor) {
            dateStampImage = cg
            dateImprint = nsImage(cg)
        }
        if let signature, let cg = StampRenderer.makeSignatureImprint(signature: signature, ink: inkColor) {
            signatureStampImage = cg
            signatureImprint = nsImage(cg)
        } else {
            signatureStampImage = nil
            signatureImprint = nil
        }
    }

    private func nsImage(_ cg: CGImage) -> NSImage {
        NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / StampRenderer.renderScale,
                                          height: CGFloat(cg.height) / StampRenderer.renderScale))
    }

    // MARK: - Documento

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.message = "Elige el PDF que quieres firmar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let doc = PDFDocument(url: url) else { return }
        placements.removeAll()
        selectedID = nil
        documentURL = url
        document = doc
    }

    // MARK: - Estampar

    func placeStamp(kind: StampKind, atLocalPoint point: CGPoint) -> Bool {
        guard let pdfView, let doc = pdfView.document,
              let page = pdfView.page(for: point, nearest: false) else { return false }
        guard let image = stampImage(for: kind) else { return false }

        let base = Self.baseSize(for: kind)
        let size = CGSize(width: base.width * stampScale, height: base.height * stampScale)
        var center = pdfView.convert(point, to: page)
        let pb = page.bounds(for: pdfView.displayBox)
        center.x = min(max(center.x, pb.minX + size.width / 2), pb.maxX - size.width / 2)
        center.y = min(max(center.y, pb.minY + size.height / 2), pb.maxY - size.height / 2)

        let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                          width: size.width, height: size.height)
        placements.append(PlacedStamp(id: UUID(), kind: kind, image: image,
                                      pageIndex: doc.index(for: page), pageRect: rect))
        return true
    }

    func selectPlaced(_ id: UUID?) {
        selectedID = id
    }

    func updateRect(_ id: UUID, to rect: CGRect) {
        if let index = placements.firstIndex(where: { $0.id == id }) {
            placements[index].pageRect = rect
        }
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        placements.removeAll { $0.id == id }
        selectedID = nil
    }

    func undo() {
        guard let last = placements.popLast() else { return }
        if selectedID == last.id { selectedID = nil }
    }

    func clearPlacements() {
        placements.removeAll()
        selectedID = nil
    }

    // MARK: - Guardar

    func save() {
        guard let url = documentURL else { return }
        guard !placements.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let base = url.deletingPathExtension().lastPathComponent
        panel.nameFieldStringValue = base + "-firmado.pdf"
        panel.message = "Guardar el PDF firmado como un archivo nuevo"
        guard panel.runModal() == .OK, let out = panel.url else { return }

        try? PDFExporter.export(sourceURL: url, placements: placements, to: out)
    }
}
