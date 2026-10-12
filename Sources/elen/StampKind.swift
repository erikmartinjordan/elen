import Foundation

enum StampKind: String {
    case fecha
    case firma

    var title: String {
        switch self {
        case .fecha: return "Fecha"
        case .firma: return "Firma"
        }
    }
}
