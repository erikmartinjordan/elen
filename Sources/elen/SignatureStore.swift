import AppKit

/// Gestiona la biblioteca de firmas del usuario en Application Support.
enum SignatureStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("elen", isDirectory: true)
        let legacy = base.appendingPathComponent("Firmador", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.moveItem(at: legacy, to: dir)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var signaturesDirectory: URL {
        let dir = directory.appendingPathComponent("firmas", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let selectedKey = "selectedSignature"

    static func loadAll() -> [StoredSignature] {
        let fm = FileManager.default
        migrateLegacyIfNeeded()
        let urls = (try? fm.contentsOfDirectory(at: signaturesDirectory,
                                                includingPropertiesForKeys: [.creationDateKey])) ?? []
        let pngs = urls.filter { $0.pathExtension.lowercased() == "png" }
        let sorted = pngs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da < db
        }
        return sorted.compactMap { url in
            guard let image = NSImage(contentsOf: url) else { return nil }
            return StoredSignature(id: url, image: image)
        }
    }

    @discardableResult
    static func add(_ image: NSImage) -> StoredSignature? {
        let url = signaturesDirectory.appendingPathComponent("firma-\(UUID().uuidString).png")
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        do {
            try png.write(to: url)
            return StoredSignature(id: url, image: image)
        } catch {
            return nil
        }
    }

    static func delete(_ signature: StoredSignature) {
        try? FileManager.default.removeItem(at: signature.url)
    }

    static var selectedURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: selectedKey) else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: selectedKey)
        }
    }

    private static func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        let legacy = directory.appendingPathComponent("firma.png")
        guard fm.fileExists(atPath: legacy.path) else { return }
        let existing = (try? fm.contentsOfDirectory(at: signaturesDirectory, includingPropertiesForKeys: nil)) ?? []
        let pngs = existing.filter { $0.pathExtension.lowercased() == "png" }
        if pngs.isEmpty {
            try? fm.copyItem(at: legacy, to: signaturesDirectory.appendingPathComponent("firma.png"))
        }
    }
}
