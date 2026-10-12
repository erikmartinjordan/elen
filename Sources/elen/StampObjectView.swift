import SwiftUI

/// Sellos físicos dibujados: un fechador azul y un sello de madera, con volumen y brillos.
struct StampObjectView: View {
    let kind: StampKind
    let imprint: NSImage?
    var compact: Bool = false

    private var label: String { kind.title }

    private let blueBody = LinearGradient(
        colors: [Color(red: 0.36, green: 0.50, blue: 0.90),
                 Color(red: 0.16, green: 0.26, blue: 0.66),
                 Color(red: 0.10, green: 0.16, blue: 0.50)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        Group {
            if compact {
                object3D
            } else {
                VStack(spacing: 10) {
                    object3D
                    previewPaper
                    Text(label)
                        .font(.caption).bold()
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
        }
    }

    private var object3D: some View {
        let artwork = StampArtwork.image(for: kind)
        return ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 78, height: 13)
                .blur(radius: 5)
                .offset(y: 5)

            Group {
                if let artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 124)
                } else if kind == .fecha {
                    fechador
                } else {
                    woodenStamp
                }
            }
            .rotation3DEffect(.degrees(artwork == nil ? 8 : 0),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        }
        .frame(height: 128, alignment: .bottom)
    }

    // MARK: - Fechador

    private var fechador: some View {
        VStack(spacing: 0) {
            // Mango
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(blueBody)
                .frame(width: 54, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.05), .clear],
                                             startPoint: .topLeading, endPoint: .center))
                        .padding(EdgeInsets(top: 4, leading: 6, bottom: 20, trailing: 6))
                )
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1.5)

            // Cuello metálico
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.4)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 30, height: 9)

            // Cuerpo
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(blueBody)
                .frame(width: 96, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.15)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 74, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(.black.opacity(0.12), lineWidth: 0.5)
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1.5)

            // Base / almohadilla
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.12)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 102, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.45), lineWidth: 1))
        }
    }

    // MARK: - Sello de madera

    private var woodenStamp: some View {
        VStack(spacing: 0) {
            // Mango torneado
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.82, green: 0.58, blue: 0.30),
                                              Color(red: 0.55, green: 0.34, blue: 0.13),
                                              Color(red: 0.34, green: 0.19, blue: 0.06)],
                                     center: UnitPoint(x: 0.34, y: 0.28),
                                     startRadius: 3, endRadius: 44))
                .frame(width: 52, height: 52)
                .overlay(
                    Ellipse()
                        .fill(LinearGradient(colors: [.white.opacity(0.65), .clear],
                                             startPoint: .topLeading, endPoint: .center))
                        .frame(width: 26, height: 20)
                        .offset(x: -8, y: -11)
                        .blur(radius: 1)
                )
                .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 2, y: 2)

            // Cuello
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [Color(red: 0.6, green: 0.38, blue: 0.15),
                                              Color(red: 0.36, green: 0.20, blue: 0.07)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 22, height: 8)

            // Pestaña ancha
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(red: 0.68, green: 0.44, blue: 0.19),
                                              Color(red: 0.40, green: 0.23, blue: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 40, height: 10)

            // Virola metálica
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.6), Color(white: 0.45)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 44, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.2), lineWidth: 0.5))

            // Base de goma
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(red: 0.24, green: 0.24, blue: 0.26),
                                              Color(red: 0.06, green: 0.06, blue: 0.08)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 90, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.45), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1.5)
        }
    }

    // MARK: - Vista previa

    private var previewPaper: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 3)
            if let imprint {
                Image(nsImage: imprint)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
        }
        .frame(width: kind == .fecha ? 122 : 128, height: 46)
    }
}
