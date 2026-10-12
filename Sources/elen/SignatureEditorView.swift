import SwiftUI
import AppKit

/// Editor para crear una firma nueva: dibujándola o escaneándola con la cámara.
struct SignatureCaptureView: View {
    let onSave: (NSImage) -> Void
    let onCancel: () -> Void

    @StateObject private var drawController = DrawingController()
    @StateObject private var camera = CameraController()
    @State private var mode = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Nueva firma").font(.title2).bold()

            Picker("", selection: $mode) {
                Text("Dibujar").tag(0)
                Text("Cámara").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: mode) { _, newValue in
                if newValue == 1 { camera.start() } else { camera.stop() }
            }

            ZStack {
                if mode == 0 {
                    SignatureCanvas(controller: drawController)
                } else {
                    cameraTab
                }
            }
            .frame(width: 520, height: 240)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))

            if mode == 1 {
                Text(camera.status)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 520)
                Button { camera.capture() } label: { Label("Capturar", systemImage: "camera") }
            } else {
                Text("Dibuja tu firma con el trackpad, como si firmaras en un papel.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancelar") { camera.stop(); onCancel() }
                if mode == 0 {
                    Button("Deshacer") { drawController.undo() }
                        .disabled(drawController.isEmpty)
                    Button("Borrar todo") { drawController.clear() }
                        .disabled(drawController.isEmpty)
                }
                Spacer()
                Button("Guardar firma") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .onDisappear { camera.stop() }
    }

    private var cameraTab: some View {
        Group {
            if let processed = camera.processed {
                Image(nsImage: processed)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .background(Color.white)
            } else {
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var canSave: Bool {
        mode == 0 ? !drawController.isEmpty : camera.processed != nil
    }

    private func save() {
        if mode == 0, let image = drawController.currentImage() {
            onSave(image)
        } else if let image = camera.processed {
            onSave(image)
        }
    }
}
