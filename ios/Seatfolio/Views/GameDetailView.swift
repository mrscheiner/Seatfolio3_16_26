import SwiftUI

struct GameDetailView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let game: Game

    @State private var pairPrices: [String: String] = [:]
    @State private var pairStatuses: [String: Bool] = [:]
    @State private var pairSaleIds: [String: String] = [:]
    @State private var seatPrices: [String: String] = [:]
    @State private var seatStatuses: [String: Bool] = [:]
    @State private var seatSaleIds: [String: String] = [:]

    private var theme: TeamTheme { store.currentTheme }

    private var sales: [Sale] {
        store.salesForGame(game.id)
    }

    private var seatPairs: [SeatPair] {
        store.activePass?.seatPairs ?? []
    }

    private var sellAsPairsOnly: Bool {
        store.activePass?.sellAsPairsOnly ?? true
    }

    private var isPast: Bool {
        game.date < Date.now
    }

    private var totalRevenue: Double {
        sales.reduce(0) { $0 + $1.price }
    }

    private var ticketsSoldCount: Int {
        if sellAsPairsOnly {
            return sales.count * 2
        } else {
            return sales.count
        }
    }

    private var fullOpponentName: String {
        guard let pass = store.activePass, !game.opponentAbbr.isEmpty else { return game.opponent }
        let name = LeagueData.teamNameForAPIAbbr(game.opponentAbbr, leagueId: pass.leagueId)
        return name == game.opponentAbbr ? game.opponent : name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    gameHeader

                    VStack(spacing: 16) {
                        gameSummaryCards

                        if seatPairs.isEmpty {
                            emptySalesState
                        } else {
                            pairEntrySection
                        }

                        if !orphanedSales.isEmpty {
                            orphanedSalesSection
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(theme.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear { loadExistingSales() }
        }
    }

    private var orphanedSales: [Sale] {
        let pairSeatSigs = Set(seatPairs.map { "\($0.section)|\($0.row)|\($0.seats)" })
        let individualSeatSigs = Set(seatPairs.flatMap { pair in pair.individualSeats.map { "\(pair.section)|\(pair.row)|\($0)" } })
        return sales.filter { sale in
            let sig = "\(sale.section)|\(sale.row)|\(sale.seats)"
            return !pairSeatSigs.contains(sig) && !individualSeatSigs.contains(sig)
        }
    }

    private func pairKey(for pair: SeatPair) -> String {
        pair.id
    }

    private func loadExistingSales() {
        for pair in seatPairs {
            let key = pairKey(for: pair)
            if let existing = sales.first(where: { $0.section == pair.section && $0.row == pair.row && $0.seats == pair.seats }) {
                pairPrices[key] = String(format: "%.0f", existing.price)
                pairStatuses[key] = existing.status == .paid
                pairSaleIds[key] = existing.id
            } else {
                pairPrices[key] = pairPrices[key] ?? ""
                pairStatuses[key] = pairStatuses[key] ?? false
            }
            for seat in pair.individualSeats {
                let sk = seatKey(for: pair, seat: seat)
                if let existing = sales.first(where: { $0.section == pair.section && $0.row == pair.row && $0.seats == seat }) {
                    seatPrices[sk] = String(format: "%.0f", existing.price)
                    seatStatuses[sk] = existing.status == .paid
                    seatSaleIds[sk] = existing.id
                } else {
                    seatPrices[sk] = seatPrices[sk] ?? ""
                    seatStatuses[sk] = seatStatuses[sk] ?? false
                }
            }
        }
    }

    private func seatKey(for pair: SeatPair, seat: String) -> String {
        "\(pair.id)|\(seat)"
    }

    private var gameHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                TeamLogoView(
                    apiAbbr: game.opponentAbbr,
                    teamName: game.opponent,
                    leagueId: store.activePass?.leagueId ?? "",
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    if !game.displayLabel.isEmpty {
                        Text("Game #\(game.displayLabel)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text("vs \(fullOpponentName)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text(game.formattedFullDate)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(TimezoneHelper.formatGameTime(game.date, teamId: store.activePass?.teamId ?? ""))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Revenue")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(totalRevenue, format: .currency(code: "USD"))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                VStack(spacing: 2) {
                    Text("Tickets Sold")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(ticketsSoldCount)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                VStack(spacing: 2) {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    let totalTickets = seatPairs.reduce(0) { $0 + $1.individualSeats.count }
                    let available = max(0, totalTickets - ticketsSoldCount)
                    Text("\(available)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                stops: [
                    .init(color: theme.primary, location: 0),
                    .init(color: theme.primary.opacity(0.9), location: 0.5),
                    .init(color: theme.secondary.opacity(0.7), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .opacity(isPast ? 0.7 : 1.0)
    }

    private var gameSummaryCards: some View {
        HStack(spacing: 10) {
            let paidCount = sales.filter { $0.status == .paid }.count
            let pendingCount = sales.filter { $0.status == .pending }.count

            MiniStatCard(
                title: "Paid",
                value: "\(paidCount)",
                color: .green
            )
            MiniStatCard(
                title: "Pending",
                value: "\(pendingCount)",
                color: .red
            )
            MiniStatCard(
                title: sellAsPairsOnly ? "Pair Sale" : "Individual",
                value: sellAsPairsOnly ? "Yes" : "OK",
                color: theme.primary
            )
        }
        .padding(.horizontal, 16)
    }

    private var emptySalesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Seat Pairs Configured")
                .font(.headline)
            Text("Add seat pairs to your season pass to log sales")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(30)
    }

    private var pairEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sellAsPairsOnly ? "Sales by Pair" : "Sales by Seat")
                .font(.title3.bold())
                .padding(.horizontal, 16)

            if sellAsPairsOnly {
                ForEach(seatPairs) { pair in
                    PairSaleCard(
                        pair: pair,
                        price: bindingForPrice(pair),
                        isPaid: bindingForStatus(pair),
                        hasExistingSale: pairSaleIds[pairKey(for: pair)] != nil,
                        theme: theme,
                        onSave: { saveSaleForPair(pair) },
                        onDelete: { deleteSaleForPair(pair) }
                    )
                    .padding(.horizontal, 16)
                }
            } else {
                ForEach(seatPairs) { pair in
                    ForEach(pair.individualSeats, id: \.self) { seat in
                        IndividualSeatSaleCard(
                            pair: pair,
                            seatLabel: seat,
                            price: bindingForSeatPrice(pair, seat: seat),
                            isPaid: bindingForSeatStatus(pair, seat: seat),
                            hasExistingSale: seatSaleIds[seatKey(for: pair, seat: seat)] != nil,
                            theme: theme,
                            onSave: { saveSaleForSeat(pair, seat: seat) },
                            onDelete: { deleteSaleForSeat(pair, seat: seat) }
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private var orphanedSalesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Sales")
                .font(.title3.bold())
                .padding(.horizontal, 16)

            ForEach(orphanedSales) { sale in
                GameSaleRow(sale: sale, theme: theme)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func bindingForSeatPrice(_ pair: SeatPair, seat: String) -> Binding<String> {
        let key = seatKey(for: pair, seat: seat)
        return Binding(
            get: { seatPrices[key] ?? "" },
            set: { seatPrices[key] = $0 }
        )
    }

    private func bindingForSeatStatus(_ pair: SeatPair, seat: String) -> Binding<Bool> {
        let key = seatKey(for: pair, seat: seat)
        return Binding(
            get: { seatStatuses[key] ?? false },
            set: { seatStatuses[key] = $0 }
        )
    }

    private func saveSaleForSeat(_ pair: SeatPair, seat: String) {
        let key = seatKey(for: pair, seat: seat)
        guard let priceStr = seatPrices[key], let priceValue = Double(priceStr), priceValue > 0 else { return }
        let isPaid = seatStatuses[key] ?? false
        let status: SaleStatus = isPaid ? .paid : .pending

        if let existingId = seatSaleIds[key],
           var existing = sales.first(where: { $0.id == existingId }) {
            existing.price = priceValue
            existing.status = status
            store.updateSale(existing)
        } else {
            let leagueId = store.activePass?.leagueId ?? ""
            let fullName = resolvedFullOpponentName(abbr: game.opponentAbbr, fallback: game.opponent, leagueId: leagueId)
            let sale = Sale(
                gameId: game.id,
                opponent: fullName,
                opponentAbbr: game.opponentAbbr,
                leagueId: leagueId,
                gameDate: game.date,
                section: pair.section,
                row: pair.row,
                seats: seat,
                price: priceValue,
                status: status
            )
            store.addSale(sale)
            seatSaleIds[key] = sale.id
        }
    }

    private func deleteSaleForSeat(_ pair: SeatPair, seat: String) {
        let key = seatKey(for: pair, seat: seat)
        if let existingId = seatSaleIds[key] {
            store.deleteSale(existingId)
            seatSaleIds.removeValue(forKey: key)
            seatPrices[key] = ""
            seatStatuses[key] = false
        }
    }

    private func bindingForPrice(_ pair: SeatPair) -> Binding<String> {
        let key = pairKey(for: pair)
        return Binding(
            get: { pairPrices[key] ?? "" },
            set: { pairPrices[key] = $0 }
        )
    }

    private func bindingForStatus(_ pair: SeatPair) -> Binding<Bool> {
        let key = pairKey(for: pair)
        return Binding(
            get: { pairStatuses[key] ?? false },
            set: { pairStatuses[key] = $0 }
        )
    }

    private func saveSaleForPair(_ pair: SeatPair) {
        let key = pairKey(for: pair)
        guard let priceStr = pairPrices[key], let priceValue = Double(priceStr), priceValue > 0 else { return }
        let isPaid = pairStatuses[key] ?? false
        let status: SaleStatus = isPaid ? .paid : .pending

        if let existingId = pairSaleIds[key],
           var existing = sales.first(where: { $0.id == existingId }) {
            existing.price = priceValue
            existing.status = status
            store.updateSale(existing)
        } else {
            let leagueId = store.activePass?.leagueId ?? ""
            let fullName = resolvedFullOpponentName(abbr: game.opponentAbbr, fallback: game.opponent, leagueId: leagueId)
            let sale = Sale(
                gameId: game.id,
                opponent: fullName,
                opponentAbbr: game.opponentAbbr,
                leagueId: leagueId,
                gameDate: game.date,
                section: pair.section,
                row: pair.row,
                seats: pair.seats,
                price: priceValue,
                status: status
            )
            store.addSale(sale)
            pairSaleIds[key] = sale.id
        }
    }

    private func deleteSaleForPair(_ pair: SeatPair) {
        let key = pairKey(for: pair)
        if let existingId = pairSaleIds[key] {
            store.deleteSale(existingId)
            pairSaleIds.removeValue(forKey: key)
            pairPrices[key] = ""
            pairStatuses[key] = false
        }
    }

    private func resolvedFullOpponentName(abbr: String, fallback: String, leagueId: String) -> String {
        if !abbr.isEmpty {
            let name = LeagueData.teamNameForAPIAbbr(abbr, leagueId: leagueId)
            if name != abbr { return name }
        }
        return fallback
    }
}

struct PairSaleCard: View {
    let pair: SeatPair
    @Binding var price: String
    @Binding var isPaid: Bool
    let hasExistingSale: Bool
    let theme: TeamTheme
    let onSave: () -> Void
    let onDelete: () -> Void

    @FocusState private var priceFieldFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sec \(pair.section) • Row \(pair.row)")
                        .font(.subheadline.weight(.semibold))
                    Text("Seats: \(pair.seats)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if hasExistingSale {
                    statusBadge
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("$")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("Sale Amount", text: $price)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                        .focused($priceFieldFocused)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(priceFieldFocused ? theme.primary : Color(.separator), lineWidth: priceFieldFocused ? 2 : 1)
                )
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPaid = false
                    }
                } label: {
                    Text("Pending")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isPaid ? Color(.systemGray4) : Color.red)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPaid = true
                    }
                } label: {
                    Text("Paid")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isPaid ? Color.green : Color(.systemGray4))
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    onSave()
                    priceFieldFocused = false
                } label: {
                    Text(hasExistingSale ? "Update" : "Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.primary)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(price.isEmpty)
                .opacity(price.isEmpty ? 0.5 : 1)

                if hasExistingSale {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }

    private var statusBadge: some View {
        Text(isPaid ? "Paid" : "Pending")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isPaid ? Color.green : Color.red)
            .clipShape(Capsule())
    }
}

struct IndividualSeatSaleCard: View {
    let pair: SeatPair
    let seatLabel: String
    @Binding var price: String
    @Binding var isPaid: Bool
    let hasExistingSale: Bool
    let theme: TeamTheme
    let onSave: () -> Void
    let onDelete: () -> Void

    @FocusState private var priceFieldFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sec \(pair.section) • Row \(pair.row)")
                        .font(.subheadline.weight(.semibold))
                    Text("Seat: \(seatLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if hasExistingSale {
                    Text(isPaid ? "Paid" : "Pending")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(isPaid ? Color.green : Color.red)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("$")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    TextField("Sale Amount", text: $price)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                        .focused($priceFieldFocused)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(priceFieldFocused ? theme.primary : Color(.separator), lineWidth: priceFieldFocused ? 2 : 1)
                )
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPaid = false
                    }
                } label: {
                    Text("Pending")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isPaid ? Color(.systemGray4) : Color.red)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPaid = true
                    }
                } label: {
                    Text("Paid")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isPaid ? Color.green : Color(.systemGray4))
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    onSave()
                    priceFieldFocused = false
                } label: {
                    Text(hasExistingSale ? "Update" : "Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.primary)
                        .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(price.isEmpty)
                .opacity(price.isEmpty ? 0.5 : 1)

                if hasExistingSale {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct GameSaleRow: View {
    let sale: Sale
    let theme: TeamTheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sec \(sale.section) • Row \(sale.row)")
                    .font(.subheadline.weight(.medium))
                Text("Seats: \(sale.seats)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(sale.soldDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(sale.price, format: .currency(code: "USD"))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(sale.status.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(sale.status == .paid ? Color.green : Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
    }
}
