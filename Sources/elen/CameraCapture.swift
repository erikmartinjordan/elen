import SwiftUI
import AVFoundation
import AppKit

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var status = "Preparando la cámara…"
    @Published var processed: NSImage?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private let queue = DispatchQueue(label: "com.familia.firmador.camera")

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.status = "No hay permiso para usar la cámara. Actívalo en Ajustes del Sistema." }
                return
            }
            self.queue.async {
                self.configureIfNeeded()
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.status = "Coloca la firma en un papel blanco frente a la cámara y pulsa Capturar." }
            }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = NSImage(data: data) else {
            DispatchQueue.main.async { self.status = "No se pudo capturar la imagen." }
            return
        }
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let extracted = cg.flatMap { SignatureProcessing.extract(from: $0) }
        DispatchQueue.main.async {
            if let extracted {
                self.processed = NSImage(cgImage: extracted,
                                         size: NSSize(width: extracted.width, height: extracted.height))
                self.status = "Firma detectada. Pulsa 'Guardar firma y usar'."
            } else {
                self.processed = nil
                self.status = "No se detectó firma. Prueba con buena luz, fondo blanco y sin sombras."
            }
        }
    }
}

final class CameraPreviewView: NSView {
    override func makeBackingLayer() -> CALayer {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override init(frame frameRect: NSRect) { super.init(frame: frameRect); wantsLayer = true }
    required init?(coder: NSCoder) { super.init(coder: coder); wantsLayer = true }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {
        if nsView.previewLayer.session !== session { nsView.previewLayer.session = session }
    }
}
