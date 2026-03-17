import SwiftUI

struct ScheduleView: View {
    @Environment(DataStore.self) private var store
    @State private var searchText = ""
    @State private var selectedFilter: GameTypeFilter = .all
    @State private var expandedGameId: String?
    @State private var pairAmounts: [String: String] = [:]
    @State private var pairStatuses: [String: Bool] = [:]
    @State private var pairSaleIds: [String: String] = [:]

    private enum GameTypeFilter: String, CaseIterable {
        case all = "All"
        case preseason = "Preseason"
        case regular = "Regular"
        case playoff = "Playoff"
    }

    private var theme: TeamTheme { store.currentTheme }

    private var games: [Game] {
        guard let pass = store.activePass else { return [] }
        var filtered = pass.games

        if selectedFilter != .all {
            let gameType: GameType = {
                switch selectedFilter {
                case .all: return .regular
                case .preseason: return .preseason
                case .regular: return .regular
                case .playoff: return .playoff
                }
            }()
            filtered = filtered.filter { $0.type == gameType }
        }

        if !searchText.isEmpty {
            let leagueId = store.activePass?.leagueId ?? ""
            filtered = filtered.filter {
                let fullName = LeagueData.teamNameForAPIAbbr($0.opponentAbbr, leagueId: leagueId)
                return $0.opponent.localizedStandardContains(searchText) ||
                    fullName.localizedStandardContains(searchText)
            }
        }

        return filtered.sorted { $0.date < $1.date }
    }

    private var allGamesForPass: [Game] {
        guard let pass = store.activePass else { return [] }
        return pass.games
    }

    private var seatPairs: [SeatPair] {
        store.activePass?.seatPairs ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scheduleHeader

                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))

                if store.isLoadingSchedule {
                    Spacer()
                    SpinningLogoView(size: 48, message: "Loading schedule...")
                    Spacer()
                } else if allGamesForPass.isEmpty {
                    emptySchedule
                } else if games.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(theme.primary.opacity(0.5))
                        Text("No \(selectedFilter.rawValue) Games")
                            .font(.title3.weight(.semibold))
                        Text("Try selecting a different filter.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(games) { game in
                                ScheduleGameCard(
                                    game: game,
                                    sales: store.salesForGame(game.id),
                                    totalSeatPairs: store.activePass?.seatPairs.count ?? 0,
                                    leagueId: store.activePass?.leagueId ?? "",
                                    theme: theme,
                                    isExpanded: expandedGameId == game.id,
                                    seatPairs: seatPairs,
                                    teamId: store.activePass?.teamId ?? "",
                                    onTap: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            if expandedGameId == game.id {
                                                expandedGameId = nil
                                            } else {
                                                expandedGameId = game.id
                                                loadExistingSales(for: game)
                                            }
                                        }
                                    },
                                    pairAmounts: $pairAmounts,
                                    pairStatuses: $pairStatuses,
                                    onSavePair: { pair in
                                        saveSaleForPair(pair, game: game)
                                    },
                                    onDeletePair: { pair in
                                        deleteSaleForPair(pair, game: game)
                                    },
                                    onToggleStatus: { sale in
                                        toggleSaleStatus(sale)
                                    },
                                    onDeleteSale: { sale in
                                        store.deleteSale(sale.id)
                                    },
                                    pairSaleIds: pairSaleIds
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 10)

                        BottomLogoView()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(theme.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search opponents")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Schedule")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.fetchScheduleFromAPI() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.white)
                    }
                }
            }
            .task(id: store.activePassId) {
                guard let pass = store.activePass, pass.games.isEmpty, !store.isLoadingSchedule else { return }
                await store.fetchScheduleFromAPI()
            }
        }
    }

    private var scheduleHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pass = store.activePass {
                HStack(spacing: 10) {
                    TeamLogoView(
                        teamId: pass.teamId,
                        leagueId: pass.leagueId,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pass.displayTeamName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        let totalSeats = pass.seatPairs.count * pass.games.count * 2
                        let seatsSold = pass.sales.count * 2
                        Text("\(seatsSold) seats sold of \(totalSeats) available")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [theme.primary, theme.secondary.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var filterBar: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(GameTypeFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptySchedule: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(theme.primary.opacity(0.6))

            Text("No Games Yet")
                .font(.title3.weight(.semibold))

            if let error = store.scheduleError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Tap sync to fetch your team's schedule.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await store.fetchScheduleFromAPI() }
            } label: {
                Label("Sync Schedule", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pairKey(for pair: SeatPair) -> String {
        "\(pair.section)|\(pair.row)|\(pair.seats)"
    }

    private func loadExistingSales(for game: Game) {
        let gameSales = store.salesForGame(game.id)
        for pair in seatPairs {
            let key = pairKey(for: pair)
            if let existing = gameSales.first(where: { $0.section == pair.section && $0.row == pair.row && $0.seats == pair.seats }) {
                pairAmounts[key] = String(format: "%.0f", existing.price)
                pairStatuses[key] = existing.status == .paid
                pairSaleIds[key] = existing.id
            } else {
                if pairAmounts[key] == nil { pairAmounts[key] = "" }
                if pairStatuses[key] == nil { pairStatuses[key] = false }
            }
        }
    }

    private func saveSaleForPair(_ pair: SeatPair, game: Game) {
        let key = pairKey(for: pair)
        guard let priceStr = pairAmounts[key], let priceValue = Double(priceStr), priceValue > 0 else { return }
        let isPaid = pairStatuses[key] ?? false
        let status: SaleStatus = isPaid ? .paid : .pending

        if let existingId = pairSaleIds[key],
           var existing = store.salesForGame(game.id).first(where: { $0.id == existingId }) {
            existing.price = priceValue
            existing.status = status
            store.updateSale(existing)
        } else {
            let sale = Sale(
                gameId: game.id,
                opponent: game.opponent,
                opponentAbbr: game.opponentAbbr,
                leagueId: store.activePass?.leagueId ?? "",
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

    private func deleteSaleForPair(_ pair: SeatPair, game: Game) {
        let key = pairKey(for: pair)
        if let existingId = pairSaleIds[key] {
            store.deleteSale(existingId)
            pairSaleIds.removeValue(forKey: key)
            pairAmounts[key] = ""
            pairStatuses[key] = false
        }
    }

    private func toggleSaleStatus(_ sale: Sale) {
        var updated = sale
        updated.status = sale.status == .paid ? .pending : .paid
        store.updateSale(updated)
    }
}

struct ScheduleGameCard: View {
    let game: Game
    let sales: [Sale]
    let totalSeatPairs: Int
    let leagueId: String
    let theme: TeamTheme
    let isExpanded: Bool
    let seatPairs: [SeatPair]
    let teamId: String
    let onTap: () -> Void
    @Binding var pairAmounts: [String: String]
    @Binding var pairStatuses: [String: Bool]
    let onSavePair: (SeatPair) -> Void
    let onDeletePair: (SeatPair) -> Void
    let onToggleStatus: (Sale) -> Void
    let onDeleteSale: (Sale) -> Void
    var pairSaleIds: [String: String]

    private var isPast: Bool {
        game.date < Date.now
    }

    private var ticketsSold: Int {
        sales.count * 2
    }

    private var ticketsAvailable: Int {
        max(0, totalSeatPairs * 2 - ticketsSold)
    }

    private var totalRevenue: Double {
        sales.reduce(0) { $0 + $1.price }
    }

    private var allPaid: Bool {
        !sales.isEmpty && sales.allSatisfy { $0.status == .paid }
    }



    private var localTime: String {
        TimezoneHelper.formatGameTime(game.date, teamId: teamId)
    }

    private var adaptiveTextColor: Color {
        .white
    }

    private var adaptiveSecondaryTextColor: Color {
        .white.opacity(0.9)
    }

    private var adaptiveTertiaryTextColor: Color {
        .white.opacity(0.7)
    }

    private var fullOpponentName: String {
        if !game.opponentAbbr.isEmpty {
            let resolved = LeagueData.teamNameForAPIAbbr(game.opponentAbbr, leagueId: leagueId)
            if resolved != game.opponentAbbr {
                return resolved
            }
        }
        let name = game.opponent
            .replacingOccurrences(of: "vs ", with: "")
            .trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            return name
        }
        if !game.opponentAbbr.isEmpty {
            return LeagueData.teamNameForAPIAbbr(game.opponentAbbr, leagueId: leagueId)
        }
        return game.opponent
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                onTap()
            } label: {
                HStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Text(game.date.formatted(.dateTime.month(.abbreviated)))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                        Text(game.date.formatted(.dateTime.day()))
                            .font(.title.bold())
                    }
                    .foregroundStyle(adaptiveTextColor)
                    .frame(width: 52, height: 56)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            TeamLogoView(
                                apiAbbr: game.opponentAbbr,
                                teamName: game.opponent,
                                leagueId: leagueId,
                                size: 28
                            )

                            if !game.displayLabel.isEmpty {
                                Text("#\(game.displayLabel)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(adaptiveTextColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(adaptiveTextColor.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(fullOpponentName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(adaptiveTextColor)
                            .lineLimit(1)

                        Text(localTime)
                            .font(.subheadline)
                            .foregroundStyle(adaptiveSecondaryTextColor)

                        HStack(spacing: 8) {
                            Text("\(ticketsSold) sold • \(ticketsAvailable) avail")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(adaptiveSecondaryTextColor)
                            if totalRevenue > 0 {
                                Text(totalRevenue, format: .currency(code: "USD"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(adaptiveTextColor)
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        if allPaid {
                            ScheduleStatusPill(text: "Paid", isPaid: true)
                        } else if !sales.isEmpty {
                            ScheduleStatusPill(text: "Pending", isPaid: false)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(adaptiveTertiaryTextColor)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(.white.opacity(0.3))

                    if !seatPairs.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(seatPairs) { pair in
                                ScheduleInlinePairRow(
                                    pair: pair,
                                    amount: bindingForAmount(pair),
                                    isPaid: bindingForStatus(pair),
                                    hasExistingSale: pairSaleIds[pairKey(for: pair)] != nil,
                                    theme: theme,
                                    onSave: { onSavePair(pair) },
                                    onDelete: { onDeletePair(pair) }
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 14)
                    }

                    let orphaned = orphanedSales
                    if !orphaned.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(orphaned) { sale in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sec \(sale.section) • Row \(sale.row)")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(adaptiveTextColor)
                                        Text("Seats: \(sale.seats)")
                                            .font(.caption2)
                                            .foregroundStyle(adaptiveSecondaryTextColor)
                                    }
                                    Spacer()
                                    Text(sale.price, format: .currency(code: "USD"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(adaptiveTextColor)
                                    Button {
                                        onToggleStatus(sale)
                                    } label: {
                                        Text(sale.status.rawValue)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(sale.status == .paid ? Color.green : Color.red)
                                            )
                                    }
                                    Button {
                                        onDeleteSale(sale)
                                    } label: {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(adaptiveTertiaryTextColor)
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: theme.gradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        .opacity(isPast && !isExpanded ? 0.85 : 1.0)
    }
}

private extension ScheduleGameCard {
    func pairKey(for pair: SeatPair) -> String {
        "\(pair.section)|\(pair.row)|\(pair.seats)"
    }

    func bindingForAmount(_ pair: SeatPair) -> Binding<String> {
        let key = pairKey(for: pair)
        return Binding(
            get: { pairAmounts[key] ?? "" },
            set: { pairAmounts[key] = $0 }
        )
    }

    func bindingForStatus(_ pair: SeatPair) -> Binding<Bool> {
        let key = pairKey(for: pair)
        return Binding(
            get: { pairStatuses[key] ?? false },
            set: { pairStatuses[key] = $0 }
        )
    }

    var orphanedSales: [Sale] {
        let pairKeys = Set(seatPairs.map { pairKey(for: $0) })
        return sales.filter { sale in
            let key = "\(sale.section)|\(sale.row)|\(sale.seats)"
            return !pairKeys.contains(key)
        }
    }
}

struct ScheduleInlinePairRow: View {
    let pair: SeatPair
    @Binding var amount: String
    @Binding var isPaid: Bool
    let hasExistingSale: Bool
    let theme: TeamTheme
    let onSave: () -> Void
    let onDelete: () -> Void

    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sec \(pair.section) • Row \(pair.row)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Seats: \(pair.seats)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if hasExistingSale {
                    Text(isPaid ? "Paid" : "Pending")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isPaid ? Color.green : Color.red)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.subheadline.weight(.semibold))
                        .focused($amountFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(.rect(cornerRadius: 8))

                Button {
                    isPaid = false
                } label: {
                    Text("Pending")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(!isPaid ? Color.red : Color(.systemGray3))
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    isPaid = true
                } label: {
                    Text("Paid")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(isPaid ? Color.green : Color(.systemGray3))
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button {
                    onSave()
                    amountFocused = false
                } label: {
                    Text(hasExistingSale ? "Update" : "Save")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(amount.isEmpty)
                .opacity(amount.isEmpty ? 0.5 : 1)

                if hasExistingSale {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(10)
                            .background(Color.red.opacity(0.8))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.12))
        .clipShape(.rect(cornerRadius: 10))
    }
}

struct ScheduleStatusPill: View {
    let text: String
    let isPaid: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isPaid ? Color.green : Color.red)
            )
    }
}
