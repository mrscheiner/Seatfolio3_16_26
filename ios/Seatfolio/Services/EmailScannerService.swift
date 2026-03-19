import Foundation

nonisolated struct EmailSale: Identifiable, Sendable {
    let id: UUID = UUID()
    let subject: String
    let date: Date
    let parsedGame: String?
    let parsedAmount: Double?
}

class EmailScannerService {
    static func scanMockEmails() -> [EmailSale] {
        [
            EmailSale(
                subject: "Your Ticketmaster Order Confirmation - Panthers vs Rangers",
                date: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
                parsedGame: "Panthers vs Rangers",
                parsedAmount: 420.00
            ),
            EmailSale(
                subject: "Your Ticketmaster Order Confirmation - Panthers vs Leafs",
                date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
                parsedGame: "Panthers vs Leafs",
                parsedAmount: 380.00
            )
        ]
    }
}
