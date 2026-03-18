import Foundation
import SwiftUI

nonisolated enum ImportError: Error, LocalizedError, Sendable {
    case invalidData(String)
    case noActivePass

    var errorDescription: String? {
        switch self {
        case .invalidData(let detail): return "Invalid import file: \(detail)"
        case .noActivePass: return "No active season pass to import sales into"
        }
    }
}

nonisolated struct SalesWrapper: Codable, Sendable {
    let sales: [Sale]
}

@Observable
class DataStore {
    var seasonPasses: [SeasonPass] = []
    var activePassId: String?
    var isLoadingSchedule = false
    var scheduleError: String?
    var toastMessage = ""
    var showToast = false
    var appEvents: [StandaloneEvent] = []

    var activePass: SeasonPass? {
        get { seasonPasses.first { $0.id == activePassId } }
        set {
            guard let newValue, let index = seasonPasses.firstIndex(where: { $0.id == newValue.id }) else { return }
            seasonPasses[index] = newValue
        }
    }

    var hasAnyPass: Bool { !seasonPasses.isEmpty }

    var currentTheme: TeamTheme {
        guard let pass = activePass else { return .default }
        return TeamThemeProvider.theme(for: pass.teamId)
    }

    private let passesKey = "spm4_season_passes"
    private let activePassKey = "spm4_active_pass_id"
    private let eventsKey = "spm4_app_events"

    private var isFetching = false
    private var fetchTaskId: String?
    private var saveTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var isDataLoaded = false

    init() {
        print("[Import] DataStore init called (top of init)")
        loadData()
        print("[Import] DataStore after loadData, before importFromLegacyJSON")
        importFromLegacyJSON()
        importPanthersBackup()
        print("[Import] DataStore after importFromLegacyJSON")
    }

    /// One-time import from legacy Seatfolio_Converted_Import copy.json
    private func importFromLegacyJSON() {
        print("[Import] importFromLegacyJSON called (top of function)")
        let fileName = "Seatfolio_Converted_Import copy"
        let fileExt = "json"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExt) else {
            print("[Import] JSON file not found in bundle: \(fileName).\(fileExt)")
            return
        }
        print("[Import] JSON file found at: \(url)")
        do {
            let data = try Data(contentsOf: url)
            print("[Import] Loaded data, size: \(data.count) bytes")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacy = try decoder.decode(LegacyImport.self, from: data)
            print("[Import] Decoded legacy import: seatPairs=\(legacy.seatPairs.count), sales=\(legacy.sales.count), leagueId=\(legacy.leagueId)")

            // Print all team names and IDs for debugging
            for pass in seasonPasses {
                print("[Import] Existing pass: teamName=\(pass.teamName), teamId=\(pass.teamId)")
            }

            // Find the Florida Panthers pass (adjust teamId as needed)
            if let panthersIndex = seasonPasses.firstIndex(where: { $0.teamName.lowercased().contains("panther") || $0.teamId.lowercased().contains("fla") }) {
                print("[Import] Panthers pass found: \(seasonPasses[panthersIndex].teamName) (teamId: \(seasonPasses[panthersIndex].teamId))")
                // Map sales (minimal fields, adjust as needed)
                let importedSales = legacy.sales.map { sale in
                    Sale(
                        id: sale.id,
                        gameId: sale.gameId,
                        opponent: "", // Fill if you have mapping
                        opponentAbbr: "",
                        leagueId: legacy.leagueId,
                        gameDate: sale.soldDate, // No gameDate in legacy, using soldDate
                        section: sale.section,
                        row: sale.row,
                        seats: sale.seats,
                        price: sale.price,
                        soldDate: sale.soldDate,
                        status: sale.paymentStatus.lowercased() == "paid" ? .paid : .pending
                    )
                }
                let beforeCount = seasonPasses[panthersIndex].sales.count
                seasonPasses[panthersIndex].sales.append(contentsOf: importedSales)
                let afterCount = seasonPasses[panthersIndex].sales.count
                saveImmediate()
                print("[Import] Imported sales added to Panthers pass! Before: \(beforeCount), After: \(afterCount), Imported: \(importedSales.count)")
            } else {
                print("[Import] Panthers pass not found! teamName/teamId values: \(seasonPasses.map { "\($0.teamName) / \($0.teamId)" })")
            }
        } catch {
            print("[Import] Failed: \(error)")
        }
    }

    // MARK: - Legacy Import Model
    private struct LegacyImport: Codable {
        let seatPairs: [LegacySeatPair]
        let leagueId: String
        let sales: [LegacySale]
    }
    private struct LegacySeatPair: Codable {
        let id: String
        let section: String
        let seats: String
        let row: String
        let cost: Double
    }
    private struct LegacySale: Codable {
        let id: String
        let gameId: String
        let pairId: String
        let section: String
        let row: String
        let seats: String
        let seatCount: Int
        let price: Double
        let paymentStatus: String
        let soldDate: Date
    }

    private func importPanthersBackup() {
        if PanthersBackupImporter.importIfNeeded(into: &seasonPasses, activePassId: &activePassId) {
            saveImmediate()
            print("[DataStore] Panthers backup imported and saved")
        }
    }

    func loadData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: passesKey) {
            do {
                let decoded = try decoder.decode([SeasonPass].self, from: data)
                seasonPasses = decoded
            } catch {
                print("[DataStore] Failed to decode passes, attempting recovery: \(error.localizedDescription)")
                recoverCorruptedData(key: passesKey)
            }
        }

        if let data = UserDefaults.standard.data(forKey: eventsKey) {
            do {
                let decoded = try decoder.decode([StandaloneEvent].self, from: data)
                appEvents = decoded
            } catch {
                print("[DataStore] Failed to decode events, clearing: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: eventsKey)
                appEvents = []
            }
        }

        activePassId = UserDefaults.standard.string(forKey: activePassKey)
        if activePassId == nil || !seasonPasses.contains(where: { $0.id == activePassId }) {
            activePassId = seasonPasses.first?.id
        }

        isDataLoaded = true
    }

    private func recoverCorruptedData(key: String) {
        let backupKey = key + "_backup"
        if let backupData = UserDefaults.standard.data(forKey: backupKey) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let recovered = try? decoder.decode([SeasonPass].self, from: backupData) {
                seasonPasses = recovered
                print("[DataStore] Recovered \(recovered.count) passes from backup")
                return
            }
        }
        UserDefaults.standard.removeObject(forKey: key)
        seasonPasses = []
        print("[DataStore] No backup available, starting fresh")
    }

    func save() {
        guard isDataLoaded else { return }

        saveTask?.cancel()

        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.performSave()
        }
    }

    private func performSave() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(seasonPasses) {
            UserDefaults.standard.set(data, forKey: passesKey)
            UserDefaults.standard.set(data, forKey: passesKey + "_backup")
        }
        if let data = try? encoder.encode(appEvents) {
            UserDefaults.standard.set(data, forKey: eventsKey)
        }
        if let id = activePassId {
            UserDefaults.standard.set(id, forKey: activePassKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activePassKey)
        }
    }

    private func saveImmediate() {
        guard isDataLoaded else { return }
        saveTask?.cancel()
        performSave()
    }

    func showToastMessage(_ message: String) {
        toastDismissTask?.cancel()
        toastMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showToast = true
        }
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                self?.showToast = false
            }
        }
    }

    func createPass(_ pass: SeasonPass) {
        seasonPasses.append(pass)
        activePassId = pass.id
        saveImmediate()
        showToastMessage("Pass created")
    }

    func deletePass(_ passId: String) {
        let name = seasonPasses.first { $0.id == passId }?.teamName ?? "Pass"
        seasonPasses.removeAll { $0.id == passId }
        if activePassId == passId {
            activePassId = seasonPasses.first?.id
        }
        saveImmediate()
        showToastMessage("Deleted: \(name)")
    }

    func switchToPass(_ passId: String) {
        guard activePassId != passId else { return }
        activePassId = passId
        saveImmediate()
    }

    func restoreLastActivePass() {
        let savedId = UserDefaults.standard.string(forKey: activePassKey)
        if let savedId, seasonPasses.contains(where: { $0.id == savedId }) {
            activePassId = savedId
        } else if let first = seasonPasses.first {
            activePassId = first.id
            saveImmediate()
        }
    }

    func passIndex(for passId: String) -> Int? {
        seasonPasses.firstIndex { $0.id == passId }
    }

    var activePassIndex: Int {
        get {
            guard let id = activePassId else { return 0 }
            return seasonPasses.firstIndex { $0.id == id } ?? 0
        }
        set {
            guard newValue >= 0, newValue < seasonPasses.count else { return }
            let pass = seasonPasses[newValue]
            if activePassId != pass.id {
                activePassId = pass.id
                save()
            }
        }
    }

    func updatePass(_ pass: SeasonPass) {
        if let index = seasonPasses.firstIndex(where: { $0.id == pass.id }) {
            seasonPasses[index] = pass
            save()
        }
    }

    func addSale(_ sale: Sale) {
        guard activePass != nil else { return }
        snapshotBeforeChange(label: "Before adding \(sale.price.formatted(.currency(code: "USD"))) sale for \(sale.opponent)")
        guard var pass = activePass else { return }
        pass.sales.append(sale)
        updatePass(pass)
        showToastMessage("Sale saved")
    }

    func updateSale(_ sale: Sale) {
        guard var passCheck = activePass else { return }
        if let idx = passCheck.sales.firstIndex(where: { $0.id == sale.id }) {
            let oldPrice = passCheck.sales[idx].price
            snapshotBeforeChange(label: "Before updating \(sale.opponent) sale from \(oldPrice.formatted(.currency(code: "USD"))) to \(sale.price.formatted(.currency(code: "USD")))")
            guard var pass = activePass else { return }
            if let index = pass.sales.firstIndex(where: { $0.id == sale.id }) {
                pass.sales[index] = sale
                updatePass(pass)
                showToastMessage("Sale updated")
            }
        }
    }

    func deleteSale(_ saleId: String) {
        guard let passCheck = activePass else { return }
        let sale = passCheck.sales.first { $0.id == saleId }
        if let sale {
            snapshotBeforeChange(label: "Before deleting \(sale.price.formatted(.currency(code: "USD"))) sale for \(sale.opponent)")
        }
        guard var pass = activePass else { return }
        pass.sales.removeAll { $0.id == saleId }
        updatePass(pass)
        showToastMessage("Sale deleted")
    }

    func addGame(_ game: Game) {
        guard var pass = activePass else { return }
        pass.games.append(game)
        updatePass(pass)
    }

    func setGames(_ games: [Game]) {
        guard var pass = activePass else { return }
        pass.games = games
        updatePass(pass)
    }

    func fetchScheduleFromAPI() async {
        guard !isFetching else {
            print("[DataStore] Fetch already in progress, skipping")
            return
        }

        guard let pass = activePass else {
            scheduleError = "No active pass selected"
            return
        }

        let currentFetchId = UUID().uuidString
        fetchTaskId = currentFetchId
        isFetching = true
        isLoadingSchedule = true
        scheduleError = nil

        defer {
            if fetchTaskId == currentFetchId {
                isFetching = false
                isLoadingSchedule = false
            }
        }

        do {
            guard let team = LeagueData.team(for: pass.teamId) else {
                scheduleError = "Team '\(pass.teamId)' not found in league data"
                return
            }

            let season = SportsDataService.shared.seasonString(for: pass.leagueId, from: pass.seasonLabel)

            let games = try await SportsDataService.shared.fetchSchedule(
                leagueId: pass.leagueId,
                teamAbbr: team.apiAbbr,
                season: season
            )

            guard fetchTaskId == currentFetchId else {
                print("[DataStore] Fetch result discarded — pass changed during fetch")
                return
            }

            setGames(games)
            backfillSalesFromGames(games)
            scheduleError = nil
        } catch {
            guard fetchTaskId == currentFetchId else { return }
            scheduleError = error.localizedDescription
        }
    }

    private func backfillSalesFromGames(_ games: [Game]) {
        guard var pass = activePass else { return }
        let gameMap = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        var changed = false
        for i in pass.sales.indices {
            let sale = pass.sales[i]
            guard let game = gameMap[sale.gameId] else { continue }
            if sale.opponentAbbr.isEmpty && !game.opponentAbbr.isEmpty {
                pass.sales[i].opponentAbbr = game.opponentAbbr
                changed = true
            }
            if sale.opponent.isEmpty && !game.opponent.isEmpty {
                let lid = activePass?.leagueId ?? ""
                if !game.opponentAbbr.isEmpty {
                    let fullName = LeagueData.teamNameForAPIAbbr(game.opponentAbbr, leagueId: lid)
                    pass.sales[i].opponent = fullName != game.opponentAbbr ? fullName : game.opponent
                } else {
                    pass.sales[i].opponent = game.opponent
                }
                changed = true
            }
            if sale.leagueId.isEmpty, let lid = activePass?.leagueId, !lid.isEmpty {
                pass.sales[i].leagueId = lid
                changed = true
            }
        }
        if changed {
            updatePass(pass)
            print("[DataStore] Backfilled missing sale data from refreshed schedule")
        }
    }

    func cancelFetch() {
        fetchTaskId = nil
        isFetching = false
        isLoadingSchedule = false
    }

    // MARK: - App-Level Events

    func addEvent(_ event: StandaloneEvent) {
        snapshotBeforeChange(label: "Before adding event: \(event.eventName)")
        appEvents.append(event)
        save()
        showToastMessage("Event saved")
    }

    func updateEvent(_ event: StandaloneEvent) {
        if appEvents.contains(where: { $0.id == event.id }) {
            snapshotBeforeChange(label: "Before updating event: \(event.eventName)")
            if let index = appEvents.firstIndex(where: { $0.id == event.id }) {
                appEvents[index] = event
            }
            save()
        }
    }

    func deleteEvent(_ eventId: String) {
        let event = appEvents.first { $0.id == eventId }
        if let event {
            snapshotBeforeChange(label: "Before deleting event: \(event.eventName)")
        }
        appEvents.removeAll { $0.id == eventId }
        save()
        showToastMessage("Event deleted")
    }

    func createBackup(label: String) {
        guard var pass = activePass else { return }
        let backup = Backup(
            label: label,
            salesCount: pass.sales.count,
            eventsCount: appEvents.count,
            salesData: pass.sales,
            eventsData: appEvents,
            gamesData: pass.games
        )
        pass.backups.append(backup)
        updatePass(pass)
    }

    private func snapshotBeforeChange(label: String) {
        guard var pass = activePass else { return }
        let backup = Backup(
            label: label,
            salesCount: pass.sales.count,
            eventsCount: appEvents.count,
            salesData: pass.sales,
            eventsData: appEvents,
            gamesData: pass.games
        )
        if pass.backups.count > 50 {
            pass.backups.removeFirst(pass.backups.count - 50)
        }
        pass.backups.append(backup)
        if let index = seasonPasses.firstIndex(where: { $0.id == pass.id }) {
            seasonPasses[index] = pass
        }
    }

    func restoreBackup(_ backup: Backup) {
        guard var pass = activePass else { return }
        pass.sales = backup.salesData
        appEvents = backup.eventsData
        pass.games = backup.gamesData
        updatePass(pass)
    }

    func exportJSON() -> String? {
        guard let pass = activePass else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(pass) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static let csvHeaders = ["ID","Game ID","Opponent","Opponent Abbr","League","Game Date","Section","Row","Seats","Price","Sold Date","Status"]

    private static let csvDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    func exportCSV() -> String? {
        guard let pass = activePass else { return nil }
        var csv = Self.csvHeaders.joined(separator: ",") + "\n"
        for sale in pass.sales {
            let gameDate = Self.csvDateFormatter.string(from: sale.gameDate)
            let soldDate = Self.csvDateFormatter.string(from: sale.soldDate)
            let row = [
                Self.csvEscape(sale.id),
                Self.csvEscape(sale.gameId),
                Self.csvEscape(sale.opponent),
                Self.csvEscape(sale.opponentAbbr),
                Self.csvEscape(sale.leagueId),
                gameDate,
                Self.csvEscape(sale.section),
                Self.csvEscape(sale.row),
                Self.csvEscape(sale.seats),
                String(sale.price),
                soldDate,
                sale.status.rawValue
            ]
            csv += row.joined(separator: ",") + "\n"
        }
        return csv
    }

    func importCSV(_ csvString: String) throws -> String {
        guard var pass = activePass else { throw ImportError.noActivePass }

        let lines = csvString.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count > 1 else { throw ImportError.invalidData("CSV file is empty or has no data rows") }

        let headerLine = lines[0].lowercased()
        let headers = Self.parseCSVRow(headerLine)

        func colIndex(_ names: [String]) -> Int? {
            for name in names {
                if let idx = headers.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == name }) {
                    return idx
                }
            }
            return nil
        }

        let idIdx = colIndex(["id"])
        let gameIdIdx = colIndex(["game id", "gameid"])
        let opponentIdx = colIndex(["opponent"])
        let opponentAbbrIdx = colIndex(["opponent abbr", "opponentabbr"])
        let leagueIdx = colIndex(["league", "leagueid", "league id"])
        let gameDateIdx = colIndex(["game date", "gamedate", "date"])
        let sectionIdx = colIndex(["section"])
        let rowIdx = colIndex(["row"])
        let seatsIdx = colIndex(["seats"])
        let priceIdx = colIndex(["price"])
        let soldDateIdx = colIndex(["sold date", "solddate"])
        let statusIdx = colIndex(["status"])

        guard let _ = priceIdx else {
            throw ImportError.invalidData("CSV missing required 'Price' column")
        }

        var importedSales: [Sale] = []
        for i in 1..<lines.count {
            let fields = Self.parseCSVRow(lines[i])
            guard fields.count > 1 else { continue }

            func field(_ idx: Int?) -> String {
                guard let idx, idx < fields.count else { return "" }
                return fields[idx].trimmingCharacters(in: .whitespaces)
            }

            let price = Double(field(priceIdx)) ?? 0
            let gameDate = Self.csvDateFormatter.date(from: field(gameDateIdx)) ?? Date()
            let soldDate = Self.csvDateFormatter.date(from: field(soldDateIdx)) ?? Date()
            let statusStr = field(statusIdx).lowercased()
            let status: SaleStatus = statusStr == "paid" ? .paid : statusStr == "per seat" ? .perSeat : .pending

            let sale = Sale(
                id: field(idIdx).isEmpty ? UUID().uuidString : field(idIdx),
                gameId: field(gameIdIdx),
                opponent: field(opponentIdx),
                opponentAbbr: field(opponentAbbrIdx),
                leagueId: field(leagueIdx).isEmpty ? (pass.leagueId) : field(leagueIdx),
                gameDate: gameDate,
                section: field(sectionIdx),
                row: field(rowIdx),
                seats: field(seatsIdx),
                price: price,
                soldDate: soldDate,
                status: status
            )
            importedSales.append(sale)
        }

        guard !importedSales.isEmpty else {
            throw ImportError.invalidData("No valid sales rows found in CSV")
        }

        let existingIds = Set(pass.sales.map { $0.id })
        let newSales = importedSales.filter { !existingIds.contains($0.id) }
        if newSales.isEmpty && !importedSales.isEmpty {
            pass.sales = importedSales
            updatePass(pass)
            return "Updated \(importedSales.count) sales from CSV for \(pass.teamName)"
        } else {
            pass.sales.append(contentsOf: newSales)
            updatePass(pass)
            return "Added \(newSales.count) sales from CSV to \(pass.teamName)"
        }
    }

    private static func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    func importJSON(_ jsonString: String) throws -> String {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasPrefix("{") && !trimmed.hasPrefix("[") {
            return try importCSV(jsonString)
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidData("File could not be read as text")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try 1: Decode as a full SeasonPass
        if let pass = try? decoder.decode(SeasonPass.self, from: data) {
            if let index = seasonPasses.firstIndex(where: { $0.id == pass.id }) {
                seasonPasses[index] = pass
                saveImmediate()
                return "Imported \(pass.sales.count) sales for \(pass.teamName)"
            } else {
                seasonPasses.append(pass)
                activePassId = pass.id
                saveImmediate()
                return "Imported pass: \(pass.teamName) with \(pass.sales.count) sales"
            }
        }

        // Try 2: Decode as an array of Sales and merge into active pass
        if let sales = try? decoder.decode([Sale].self, from: data) {
            guard var pass = activePass else {
                throw ImportError.noActivePass
            }
            let existingIds = Set(pass.sales.map { $0.id })
            let newSales = sales.filter { !existingIds.contains($0.id) }
            if newSales.isEmpty && !sales.isEmpty {
                pass.sales = sales
                updatePass(pass)
                return "Updated \(sales.count) existing sales for \(pass.teamName)"
            } else {
                pass.sales.append(contentsOf: newSales)
                updatePass(pass)
                return "Added \(newSales.count) sales to \(pass.teamName)"
            }
        }

        // Try 3: Decode as a wrapper object with a "sales" key
        if let wrapper = try? decoder.decode(SalesWrapper.self, from: data) {
            guard var pass = activePass else {
                throw ImportError.noActivePass
            }
            let existingIds = Set(pass.sales.map { $0.id })
            let newSales = wrapper.sales.filter { !existingIds.contains($0.id) }
            if newSales.isEmpty && !wrapper.sales.isEmpty {
                pass.sales = wrapper.sales
                updatePass(pass)
                return "Updated \(wrapper.sales.count) existing sales for \(pass.teamName)"
            } else {
                pass.sales.append(contentsOf: newSales)
                updatePass(pass)
                return "Added \(newSales.count) sales to \(pass.teamName)"
            }
        }

        // Try 4: Get the actual decode error for the SeasonPass attempt
        do {
            _ = try decoder.decode(SeasonPass.self, from: data)
            throw ImportError.invalidData("Unknown decode issue")
        } catch let error as DecodingError {
            switch error {
            case .keyNotFound(let key, _):
                throw ImportError.invalidData("Missing field: \(key.stringValue)")
            case .typeMismatch(let type, let context):
                throw ImportError.invalidData("Wrong type for \(context.codingPath.map { $0.stringValue }.joined(separator: ".")): expected \(type)")
            case .valueNotFound(_, let context):
                throw ImportError.invalidData("Null value at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                throw ImportError.invalidData("Corrupted data: \(context.debugDescription)")
            @unknown default:
                throw ImportError.invalidData(error.localizedDescription)
            }
        } catch {
            throw ImportError.invalidData(error.localizedDescription)
        }
    }

    func salesForGame(_ gameId: String) -> [Sale] {
        activePass?.sales.filter { $0.gameId == gameId } ?? []
    }

    func revenueForGame(_ gameId: String) -> Double {
        salesForGame(gameId).reduce(0) { $0 + $1.price }
    }

    func salesForSeatPair(section: String, row: String, seats: String) -> [Sale] {
        activePass?.sales.filter { $0.section == section && $0.row == row && $0.seats == seats } ?? []
    }
}
