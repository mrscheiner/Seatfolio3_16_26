import Foundation

enum PanthersBackupImporter {

    private static let opponentAbbrMap: [String: String] = [
        "Chicago Blackhawks": "chi",
        "Philadelphia Flyers": "phi",
        "Ottawa Senators": "ott",
        "Pittsburgh Penguins": "pit",
        "Vegas Golden Knights": "vgk",
        "Anaheim Ducks": "ana",
        "Dallas Stars": "dal",
        "Washington Capitals": "wsh",
        "Tampa Bay Lightning": "tbl",
        "Vancouver Canucks": "van",
        "New Jersey Devils": "njd",
        "Edmonton Oilers": "edm",
        "Calgary Flames": "cgy",
        "Toronto Maple Leafs": "tor",
        "Nashville Predators": "nsh",
        "Columbus Blue Jackets": "cbj",
        "New York Islanders": "nyi",
        "Los Angeles Kings": "lak",
        "Carolina Hurricanes": "car",
        "St. Louis Blues": "stl",
        "Montreal Canadiens": "mtl",
        "Colorado Avalanche": "col",
        "San Jose Sharks": "sjs",
        "Utah Mammoth": "uta",
        "Winnipeg Jets": "wpg",
        "Buffalo Sabres": "buf",
        "Boston Bruins": "bos",
        "Detroit Red Wings": "det",
        "Seattle Kraken": "sea",
        "Minnesota Wild": "min",
        "New York Rangers": "nyr",
        "Florida Panthers": "fla"
    ]

    static func importIfNeeded(into passes: inout [SeasonPass], activePassId: inout String?) -> Bool {
        let importKey = "panthers_backup_imported_v1"
        guard !UserDefaults.standard.bool(forKey: importKey) else { return false }

        guard let url = Bundle.main.url(forResource: "SeasonPassBackup_2026-02-22", withExtension: "json") else {
            print("[PanthersImport] Backup JSON not found in bundle")
            return false
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let passesArray = json?["seasonPasses"] as? [[String: Any]],
                  let passDict = passesArray.first else {
                print("[PanthersImport] Could not parse seasonPasses array")
                return false
            }

            let pass = try parsePass(passDict)

            if let existingIdx = passes.firstIndex(where: { $0.teamId == "fla" && $0.leagueId == "nhl" }) {
                passes[existingIdx] = pass
            } else {
                passes.append(pass)
            }
            activePassId = pass.id

            UserDefaults.standard.set(true, forKey: importKey)
            print("[PanthersImport] Successfully imported \(pass.sales.count) sales, \(pass.games.count) games")
            return true
        } catch {
            print("[PanthersImport] Failed: \(error)")
            return false
        }
    }

    private static func parsePass(_ dict: [String: Any]) throws -> SeasonPass {
        let id = dict["id"] as? String ?? UUID().uuidString
        let leagueId = dict["leagueId"] as? String ?? "nhl"
        let teamId = dict["teamId"] as? String ?? "fla"
        let teamName = dict["teamName"] as? String ?? "Florida Panthers"
        let seasonLabel = dict["seasonLabel"] as? String ?? "2025-2026"

        let seatPairsRaw = dict["seatPairs"] as? [[String: Any]] ?? []
        let seatPairs = seatPairsRaw.map { sp in
            SeatPair(
                id: sp["id"] as? String ?? UUID().uuidString,
                section: sp["section"] as? String ?? "",
                row: sp["row"] as? String ?? "",
                seats: sp["seats"] as? String ?? "",
                cost: sp["seasonCost"] as? Double ?? sp["cost"] as? Double ?? 0
            )
        }

        let gamesRaw = dict["games"] as? [[String: Any]] ?? []
        var gameMap: [String: (opponent: String, opponentAbbr: String, date: Date)] = [:]
        let games: [Game] = gamesRaw.compactMap { g in
            guard let gid = g["id"] as? String else { return nil }
            let rawOpponent = g["opponent"] as? String ?? ""
            let opponent = rawOpponent.replacingOccurrences(of: "vs ", with: "")
            let opponentAbbr = opponentAbbrMap[opponent] ?? ""
            let time = g["time"] as? String ?? ""
            let typeStr = g["type"] as? String ?? "Regular"
            let gameType: GameType = typeStr == "Preseason" ? .preseason : .regular
            let gameNumStr = g["gameNumber"] as? String ?? "\(g["gameNumber"] as? Int ?? 0)"
            let gameNumber = Int(gameNumStr.replacingOccurrences(of: "PS ", with: "")) ?? 0

            let iso = g["dateTimeISO"] as? String ?? ""
            let date = parseISO(iso) ?? Date()

            gameMap[gid] = (opponent, opponentAbbr, date)

            return Game(
                id: gid,
                date: date,
                opponent: opponent,
                opponentAbbr: opponentAbbr,
                venueName: "",
                time: time,
                gameNumber: gameNumber,
                gameLabel: gameNumStr.contains("PS") ? gameNumStr : "",
                type: gameType,
                isHome: true
            )
        }

        let salesDataRaw = dict["salesData"] as? [String: [String: Any]] ?? [:]
        var sales: [Sale] = []
        for (gameId, pairsDict) in salesDataRaw {
            let gameInfo = gameMap[gameId]
            for (_, saleAny) in pairsDict {
                guard let saleDict = saleAny as? [String: Any] else { continue }
                let saleId = saleDict["id"] as? String ?? UUID().uuidString
                let section = saleDict["section"] as? String ?? ""
                let row = saleDict["row"] as? String ?? ""
                let seats = saleDict["seats"] as? String ?? ""
                let price = saleDict["price"] as? Double ?? 0
                let paymentStatus = saleDict["paymentStatus"] as? String ?? "Pending"
                let soldDateStr = saleDict["soldDate"] as? String ?? ""
                let soldDate = parseISO(soldDateStr) ?? Date()
                let gameDate = gameInfo?.date ?? soldDate

                let status: SaleStatus = paymentStatus == "Paid" ? .paid : .pending

                let sale = Sale(
                    id: saleId,
                    gameId: gameId,
                    opponent: gameInfo?.opponent ?? "",
                    opponentAbbr: gameInfo?.opponentAbbr ?? "",
                    leagueId: leagueId,
                    gameDate: gameDate,
                    section: section,
                    row: row,
                    seats: seats,
                    price: price,
                    soldDate: soldDate,
                    status: status
                )
                sales.append(sale)
            }
        }

        sales.sort { $0.soldDate < $1.soldDate }

        let createdIso = dict["createdAtISO"] as? String ?? ""
        let createdAt = parseISO(createdIso) ?? Date()

        return SeasonPass(
            id: id,
            leagueId: leagueId,
            teamId: teamId,
            teamName: teamName,
            seasonLabel: seasonLabel,
            seatPairs: seatPairs,
            sellAsPairsOnly: true,
            sales: sales,
            games: games,
            events: [],
            backups: [],
            createdAt: createdAt
        )
    }

    private static func parseISO(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}
