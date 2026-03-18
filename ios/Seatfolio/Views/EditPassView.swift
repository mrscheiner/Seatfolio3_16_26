import SwiftUI

struct EditPassView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var seasonLabel: String
    @State private var seatPairs: [SeatPair]
    @State private var sellAsPairsOnly: Bool
    @State private var editingPairId: String?
    @State private var editSection = ""
    @State private var editRow = ""
    @State private var editSeats = ""
    @State private var editCost = ""
    @State private var newSection = ""
    @State private var newRow = ""
    @State private var newSeats = ""
    @State private var newCost = ""
    @State private var hasChanges = false
    @State private var showDiscardAlert = false

    private let passId: String

    private var theme: TeamTheme { store.currentTheme }

    init(pass: SeasonPass) {
        self.passId = pass.id
        _seasonLabel = State(initialValue: pass.seasonLabel)
        _seatPairs = State(initialValue: pass.seatPairs)
        _sellAsPairsOnly = State(initialValue: pass.sellAsPairsOnly)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Season Label", text: $seasonLabel)
                        .onChange(of: seasonLabel) { _, _ in hasChanges = true }
                } header: {
                    Text("Season Label")
                } footer: {
                    Text("e.g. 2025-2026 Season")
                }

                Section {
                    Toggle(isOn: $sellAsPairsOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sell as Pairs Only")
                                .font(.body.weight(.medium))
                            Text(sellAsPairsOnly ? "Tickets sold as pairs" : "Individual ticket sales")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(theme.primary)
                    .onChange(of: sellAsPairsOnly) { _, _ in hasChanges = true }
                }

                Section("Seat Pairs") {
                    if seatPairs.isEmpty {
                        Text("No seat pairs added")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(seatPairs) { pair in
                            if editingPairId == pair.id {
                                editPairForm(pair: pair)
                            } else {
                                seatPairRow(pair: pair)
                            }
                        }
                        .onDelete { offsets in
                            seatPairs.remove(atOffsets: offsets)
                            hasChanges = true
                        }
                    }
                }

                Section("Add Seat Pair") {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Section").font(.caption.weight(.semibold))
                            TextField("e.g. 101", text: $newSection)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Row").font(.caption.weight(.semibold))
                            TextField("e.g. A", text: $newRow)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Seats").font(.caption.weight(.semibold))
                            TextField("e.g. 1-2", text: $newSeats)
                                .textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cost").font(.caption.weight(.semibold))
                            TextField("$0.00", text: $newCost)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                        }
                    }
                    Button {
                        addSeatPair()
                    } label: {
                        Label("Add Seat Pair", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                    .disabled(newSection.isEmpty || newRow.isEmpty || newSeats.isEmpty || newCost.isEmpty)
                }
            }
            .navigationTitle("Edit Pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(seasonLabel.trimmingCharacters(in: .whitespaces).isEmpty || seatPairs.isEmpty)
                }
            }
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes that will be lost.")
            }
        }
    }

    private func seatPairRow(pair: SeatPair) -> some View {
        Button {
            beginEditing(pair)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sec \(pair.section), Row \(pair.row)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Seats: \(pair.seats)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(pair.cost, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func editPairForm(pair: SeatPair) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Section").font(.caption.weight(.semibold))
                    TextField("Section", text: $editSection)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Row").font(.caption.weight(.semibold))
                    TextField("Row", text: $editRow)
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seats").font(.caption.weight(.semibold))
                    TextField("Seats", text: $editSeats)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cost").font(.caption.weight(.semibold))
                    TextField("$0.00", text: $editCost)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
            }
            HStack(spacing: 12) {
                Button {
                    editingPairId = nil
                } label: {
                    Text("Cancel")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    applyEdit(for: pair.id)
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primary)
                .disabled(editSection.isEmpty || editRow.isEmpty || editSeats.isEmpty || editCost.isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func beginEditing(_ pair: SeatPair) {
        editingPairId = pair.id
        editSection = pair.section
        editRow = pair.row
        editSeats = pair.seats
        editCost = String(format: "%.2f", pair.cost)
    }

    private func applyEdit(for pairId: String) {
        guard let cost = Double(editCost),
              let index = seatPairs.firstIndex(where: { $0.id == pairId }) else { return }
        seatPairs[index].section = editSection.trimmingCharacters(in: .whitespaces)
        seatPairs[index].row = editRow.trimmingCharacters(in: .whitespaces)
        seatPairs[index].seats = editSeats.trimmingCharacters(in: .whitespaces)
        seatPairs[index].cost = cost
        editingPairId = nil
        hasChanges = true
    }

    private func addSeatPair() {
        guard let cost = Double(newCost) else { return }
        let pair = SeatPair(
            section: newSection.trimmingCharacters(in: .whitespaces),
            row: newRow.trimmingCharacters(in: .whitespaces),
            seats: newSeats.trimmingCharacters(in: .whitespaces),
            cost: cost
        )
        seatPairs.append(pair)
        newSection = ""
        newRow = ""
        newSeats = ""
        newCost = ""
        hasChanges = true
    }

    private func saveChanges() {
        guard var pass = store.seasonPasses.first(where: { $0.id == passId }) else { return }
        pass.seasonLabel = seasonLabel.trimmingCharacters(in: .whitespaces)
        pass.seatPairs = seatPairs
        pass.sellAsPairsOnly = sellAsPairsOnly
        store.updatePass(pass)
        store.showToastMessage("Pass updated")
    }
}
