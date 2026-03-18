import SwiftUI

struct AddSaleView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGameId = ""
    @State private var section = ""
    @State private var row = ""
    @State private var seats = ""
    @State private var price = ""
    @State private var isPaid = false
    @State private var editingSale: Sale?

    init(editingSale: Sale? = nil) {
        _editingSale = State(initialValue: editingSale)
    }

    private var games: [Game] {
        store.activePass?.games.sorted { $0.date < $1.date } ?? []
    }

    private var seatPairs: [SeatPair] {
        store.activePass?.seatPairs ?? []
    }

    private var theme: TeamTheme { store.currentTheme }

    var body: some View {
        NavigationStack {
            Form {
                if !games.isEmpty {
                    Section("Game") {
                        Picker("Select Game", selection: $selectedGameId) {
                            Text("Select a game").tag("")
                            ForEach(games) { game in
                                Text("vs \(game.opponent) — \(game.formattedDate)")
                                    .tag(game.id)
                            }
                        }
                    }
                }

                Section("Seat Info") {
                    TextField("Section", text: $section)
                    TextField("Row", text: $row)
                    TextField("Seats (e.g. 24-25)", text: $seats)

                    if !seatPairs.isEmpty {
                        Menu {
                            ForEach(seatPairs) { pair in
                                Button("Sec \(pair.section), Row \(pair.row), Seats \(pair.seats)") {
                                    section = pair.section
                                    row = pair.row
                                    seats = pair.seats
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.on.rectangle")
                                    .foregroundStyle(theme.primary)
                                Text("Autofill from Seat Pair")
                                    .foregroundStyle(theme.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Sale Details") {
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)

                    VStack(spacing: 12) {
                        HStack {
                            Text("Payment Status")
                                .font(.body)
                            Spacer()
                            Text(isPaid ? "Paid" : "Pending")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isPaid ? Color.green : Color.red)
                                .clipShape(Capsule())
                        }

                        Toggle(isOn: $isPaid) {
                            EmptyView()
                        }
                        .toggleStyle(PaymentToggleStyle())
                    }
                }
            }
            .navigationTitle(editingSale == nil ? "Add Sale" : "Edit Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSale()
                        dismiss()
                    }
                    .disabled(section.isEmpty || price.isEmpty)
                }
            }
            .onAppear {
                if let sale = editingSale {
                    selectedGameId = sale.gameId
                    section = sale.section
                    row = sale.row
                    seats = sale.seats
                    price = String(sale.price)
                    isPaid = sale.status == .paid
                }
            }
        }
    }

    private func saveSale() {
        guard let priceValue = Double(price) else { return }
        let game = games.first { $0.id == selectedGameId }
        let status: SaleStatus = isPaid ? .paid : .pending

        if var existing = editingSale {
            existing.gameId = selectedGameId
            existing.opponent = resolvedFullName(game: game)
            existing.opponentAbbr = game?.opponentAbbr ?? existing.opponentAbbr
            existing.leagueId = store.activePass?.leagueId ?? existing.leagueId
            existing.gameDate = game?.date ?? Date()
            existing.section = section
            existing.row = row
            existing.seats = seats
            existing.price = priceValue
            existing.status = status
            store.updateSale(existing)
        } else {
            let sale = Sale(
                gameId: selectedGameId,
                opponent: resolvedFullName(game: game),
                opponentAbbr: game?.opponentAbbr ?? "",
                leagueId: store.activePass?.leagueId ?? "",
                gameDate: game?.date ?? Date(),
                section: section,
                row: row,
                seats: seats,
                price: priceValue,
                status: status
            )
            store.addSale(sale)
        }
    }

    private func resolvedFullName(game: Game?) -> String {
        guard let game else { return "" }
        let leagueId = store.activePass?.leagueId ?? ""
        if !game.opponentAbbr.isEmpty {
            let name = LeagueData.teamNameForAPIAbbr(game.opponentAbbr, leagueId: leagueId)
            if name != game.opponentAbbr { return name }
        }
        return game.opponent
    }
}

struct PaymentToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: 0) {
                Text("Pending")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(configuration.isOn ? Color(.systemGray4) : Color.red)
                    .clipShape(.rect(cornerRadius: 10))

                Text("Paid")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(configuration.isOn ? Color.green : Color(.systemGray4))
                    .clipShape(.rect(cornerRadius: 10))
            }
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
