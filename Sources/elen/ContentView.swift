import SwiftUI
import PDFKit
import AppKit

struct ContentView: View {
    @StateObject private var model = AppModel()

    // Sello de la bandeja que se está "llevando" con el ratón.
    @State private var carried: StampKind?
    @State private var mouseLocation: CGPoint?

    // Animación de estampado.
    @State private var pressing = false
    @State private var pressTarget: CGPoint?
    @State private var rippleID = 0

    @State private var showSignatureMenu = false

    var body: some View {
        ZStack {
            DeskBackground()

            VStack(spacing: 0) {
                topBar
                ZStack(alignment: .top) {
                    PDFViewContainer(
                        document: model.document,
                        placements: model.placements,
                        selectedID: model.selectedID,
                        placementEnabled: carried != nil,
                        editingEnabled: carried == nil && model.document != nil,
                        previewImage: carried.flatMap { model.stampImage(for: $0) },
                        previewLogicalSize: carried.map { model.logicalSize(for: $0) } ?? .zero,
                        onPlace: { point in handlePlace(viewPoint: point) },
                        onSelect: { id in model.selectPlaced(id) },
                        onMoveCommit: { id, rect in model.updateRect(id, to: rect) },
                        onResizeCommit: { id, rect in model.updateRect(id, to: rect) },
                        onCreated: { view in model.pdfView = view }
                    )
                    if model.document == nil { emptyState }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if model.document != nil {
                        StampsTrayView(model: model, carried: $carried)
                    }
                }
                .padding(24)
            }

            // Animación: sello bajando y "golpe".
            if let kind = carried, let location = mouseLocation {
                StampObjectView(kind: kind, imprint: model.imprint(for: kind), compact: true)
                    .frame(width: 88)
                    .scaleEffect(pressing ? 0.9 : 1)
                    .rotationEffect(.degrees(pressing ? 0 : 8))
                    .position(objectPosition(held: location))
                    .opacity(0.97)
                    .allowsHitTesting(false)
            }

            if rippleID > 0, let target = pressTarget {
                RippleView()
                    .position(target)
                    .id(rippleID)
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "root")
        .onContinuousHover(coordinateSpace: .named("root")) { phase in
            switch phase {
            case .active(let location): mouseLocation = location
            case .ended: mouseLocation = nil
            }
        }
        .frame(minWidth: 1040, minHeight: 720)
        .onExitCommand { carried = nil }
        .onDeleteCommand { model.deleteSelected() }
        .onChange(of: model.selectedID) { _, newValue in
            if newValue != nil { carried = nil }
        }
        .onAppear { model.loadSignatureIfNeeded() }
        .sheet(isPresented: $model.showSignatureEditor) {
            SignatureCaptureView(
                onSave: { image in
                    model.addSignature(image)
                    model.showSignatureEditor = false
                    carried = .firma
                },
                onCancel: { model.showSignatureEditor = false }
            )
            .padding(20)
            .frame(width: 600)
        }
    }

    // MARK: - Posición del sello mientras se "lleva"

    private func objectPosition(held location: CGPoint) -> CGPoint {
        if pressing, let target = pressTarget { return target }
        return CGPoint(x: location.x + 62, y: location.y - 74)
    }

    private func handlePlace(viewPoint: CGPoint) {
        guard let kind = carried else { return }
        let target = mouseLocation
        guard model.placeStamp(kind: kind, atLocalPoint: viewPoint) else { return }
        StampSound.shared.play()
        guard let target else { return }
        pressTarget = target
        withAnimation(.easeIn(duration: 0.10)) { pressing = true }
        rippleID += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.6)) { pressing = false }
        }
    }

    // MARK: - Barra superior

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { model.openDocument() } label: {
                Label("Abrir documento", systemImage: "doc")
            }
            .buttonStyle(.borderedProminent)

            if !model.documentName.isEmpty {
                Text(model.documentName)
                    .font(.callout).bold()
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer()

            signatureMenu

            Button { model.deleteSelected() } label: {
                Label("Eliminar", systemImage: "trash")
            }
            .disabled(!model.hasSelection)

            Button { model.undo() } label: {
                Label("Deshacer", systemImage: "arrow.uturn.backward")
            }
            .disabled(model.placementCount == 0)

            Button { model.save() } label: {
                Label("Guardar PDF", systemImage: "square.and.arrow.down")
            }
            .disabled(model.placementCount == 0 || model.document == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.35))
    }

    // MARK: - Selector de firmas (desplegable)

    private var signatureMenu: some View {
        Button {
            showSignatureMenu.toggle()
        } label: {
            Label("Firma", systemImage: "signature")
        }
        .popover(isPresented: $showSignatureMenu, arrowEdge: .bottom) {
            SignatureMenuView(
                model: model,
                onSelect: { showSignatureMenu = false },
                onAdd: {
                    showSignatureMenu = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        model.showSignatureEditor = true
                    }
                }
            )
        }
    }

    // MARK: - Estado vacío

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.7))
            Text("Abre un documento para empezar")
                .font(.title3).bold()
                .foregroundStyle(.secondary)
            Text("Elige un sello de abajo y haz clic en el papel.")
                .font(.callout)
                .foregroundStyle(.secondary.opacity(0.8))
        }
        .padding(36)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Desplegable de firmas: muestra cada firma con su miniatura y una ✕ para borrarla.
struct SignatureMenuView: View {
    @ObservedObject var model: AppModel
    let onSelect: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if model.signatures.isEmpty {
                Text("No hay firmas guardadas")
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                ForEach(Array(model.signatures.enumerated()), id: \.element.id) { index, signature in
                    row(index: index, signature: signature)
                }
            }

            Divider().padding(.vertical, 4)

            Button {
                onAdd()
            } label: {
                Label("Añadir firma…", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .padding(8)
        .frame(width: 320)
    }

    private func row(index: Int, signature: StoredSignature) -> some View {
        let isSelected = signature.id == model.selectedSignatureID
        return HStack(spacing: 10) {
            Image(nsImage: signature.image)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 36)
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))

            Text("Firma \(index + 1)")

            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
            }

            Spacer(minLength: 12)

            Button {
                model.deleteSignature(signature)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Eliminar esta firma")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectSignature(signature)
            onSelect()
        }
    }
}

/// Bandeja de sellos con controles, del tamaño original, movible arrastrando el asa superior.
struct StampsTrayView: View {
    @ObservedObject var model: AppModel
    @Binding var carried: StampKind?

    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    var body: some View {
        VStack(spacing: 14) {
            controls
            HStack(spacing: 26) {
                trayStamp(.fecha)
                trayStamp(.firma)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
        )
        .overlay(alignment: .top) {
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.5))
                    .frame(width: 44, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 13)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        offset = CGSize(width: dragStart.width + value.translation.width,
                                        height: dragStart.height + value.translation.height)
                    }
                    .onEnded { _ in dragStart = offset }
            )
        }
        .offset(offset)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("Tinta").font(.caption).foregroundStyle(.white.opacity(0.9))
                ColorPicker("", selection: inkBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 34)
            }

            Divider().frame(height: 20)

            HStack(spacing: 6) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Slider(value: sizeBinding, in: 0.5...2.0)
                    .frame(width: 120)
                Text(sizeLabel)
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 74, alignment: .leading)
            }
        }
    }

    private var inkBinding: Binding<Color> {
        Binding(get: { Color(nsColor: model.inkColor) },
                set: { model.setInk(NSColor($0)) })
    }

    private var sizeBinding: Binding<Double> {
        Binding(get: { Double(model.effectiveScale) },
                set: { model.setScale(CGFloat($0)) })
    }

    private var sizeLabel: String {
        let pct = Int(model.effectiveScale * 100)
        return "\(pct)%" + (model.hasSelection ? " (sello)" : "")
    }

    private func trayStamp(_ kind: StampKind) -> some View {
        StampObjectView(kind: kind, imprint: model.imprint(for: kind))
            .opacity(carried == kind ? 0.35 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(carried == kind ? Color.yellow.opacity(0.9) : .clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
            .onTapGesture { toggle(kind) }
    }

    private func toggle(_ kind: StampKind) {
        if kind == .firma && model.signature == nil {
            model.showSignatureEditor = true
            return
        }
        model.selectPlaced(nil)
        carried = (carried == kind) ? nil : kind
    }
}

struct RippleView: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(Color.black.opacity(0.4), lineWidth: 3)
            .frame(width: 44, height: 44)
            .scaleEffect(animate ? 2.1 : 0.6)
            .opacity(animate ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 0.38)) { animate = true }
            }
    }
}

// MARK: - Escritorio

struct DeskBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.38, green: 0.25, blue: 0.15),
                                    Color(red: 0.20, green: 0.13, blue: 0.07)],
                           startPoint: .top, endPoint: .bottom)

            Canvas { context, size in
                var y: CGFloat = 0
                var offset: CGFloat = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y + offset))
                    context.stroke(path, with: .color(.black.opacity(0.06)), lineWidth: 1)
                    y += 13
                    offset += 0.6
                }
            }
            .blendMode(.multiply)
            .opacity(0.7)

            RadialGradient(colors: [.clear, .black.opacity(0.45)],
                           center: .center, startRadius: 180, endRadius: 1000)
        }
        .ignoresSafeArea()
    }
}
