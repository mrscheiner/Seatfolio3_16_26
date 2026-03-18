import Foundation

nonisolated enum ScheduleError: LocalizedError, Sendable {
    case noAPIKey
    case unsupportedLeague(String)
    case invalidURL(String)
    case httpError(Int, String)
    case decodingFailed(String)
    case noHomeGames(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .noAPIKey: return "API key not configured. Check environment variables."
        case .unsupportedLeague(let l): return "Unsupported league: \(l)"
        case .invalidURL(let u): return "Invalid URL: \(u)"
        case .httpError(let code, let detail): return "HTTP \(code): \(detail)"
        case .decodingFailed(let msg): return "Parse error: \(msg)"
        case .noHomeGames(let team): return "No home games found for \(team)"
        }
    }
}

nonisolated struct ESPNScheduleResponse: Decodable, Sendable {
    let events: [ESPNEvent]
}

nonisolated struct ESPNScoreboardResponse: Decodable, Sendable {
    let leagues: [ESPNLeagueInfo]?
    let events: [ESPNEvent]?
}

nonisolated struct ESPNLeagueInfo: Decodable, Sendable {
    let calendar: [String]?
}

nonisolated struct ESPNEvent: Decodable, Sendable {
    let id: String
    let date: String
    let competitions: [ESPNCompetition]
    let seasonType: ESPNSeasonType?
}

nonisolated struct ESPNSeasonType: Decodable, Sendable {
    let name: String?
}

nonisolated struct ESPNCompetition: Decodable, Sendable {
    let competitors: [ESPNCompetitor]
    let venue: ESPNVenue?
}

nonisolated struct ESPNCompetitor: Decodable, Sendable {
    let homeAway: String
    let team: ESPNTeam
}

nonisolated struct ESPNTeam: Decodable, Sendable {
    let abbreviation: String
    let displayName: String?
}

nonisolated struct ESPNVenue: Decodable, Sendable {
    let fullName: String?
}

nonisolated struct SDScheduleGame: Decodable, Sendable {
    let gameID: Int?
    let gameKey: String?
    let gameId: Int?
    let season: Int?
    let seasonType: Int?
    let status: String?
    let day: String?
    let dateTime: String?
    let dateField: String?
    let awayTeam: String?
    let homeTeam: String?
    let homeTeamKey: String?
    let awayTeamKey: String?
    let homeTeamId: Int?
    let awayTeamId: Int?
    let stadiumID: Int?
    let awayTeamScore: Int?
    let homeTeamScore: Int?
    let week: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case gameID = "GameID"
        case gameKey = "GameKey"
        case gameId = "GameId"
        case season = "Season"
        case seasonType = "SeasonType"
        case status = "Status"
        case day = "Day"
        case dateTime = "DateTime"
        case dateField = "Date"
        case awayTeam = "AwayTeam"
        case homeTeam = "HomeTeam"
        case homeTeamKey = "HomeTeamKey"
        case awayTeamKey = "AwayTeamKey"
        case homeTeamId = "HomeTeamId"
        case awayTeamId = "AwayTeamId"
        case stadiumID = "StadiumID"
        case awayTeamScore = "AwayTeamScore"
        case homeTeamScore = "HomeTeamScore"
        case week = "Week"
    }

    var resolvedGameID: String {
        if let id = gameID { return "\(id)" }
        if let id = gameId { return "\(id)" }
        if let key = gameKey { return key }
        return UUID().uuidString
    }

    var resolvedHomeTeam: String {
        homeTeam ?? homeTeamKey ?? ""
    }

    var resolvedAwayTeam: String {
        awayTeam ?? awayTeamKey ?? ""
    }

    var resolvedDateTime: String? {
        dateTime ?? dateField ?? day
    }
}

private nonisolated struct LeagueEndpointConfig: Sendable {
    let basePath: String
    let endpoint: String
    let hasPreseason: Bool
}

nonisolated private let leagueConfigs: [String: LeagueEndpointConfig] = [
    "nba": LeagueEndpointConfig(basePath: "nba/scores/json", endpoint: "SchedulesBasic", hasPreseason: true),
    "nfl": LeagueEndpointConfig(basePath: "nfl/scores/json", endpoint: "Schedules", hasPreseason: true),
    "nhl": LeagueEndpointConfig(basePath: "nhl/scores/json", endpoint: "Games", hasPreseason: true),
    "mlb": LeagueEndpointConfig(basePath: "mlb/scores/json", endpoint: "Games", hasPreseason: false),
]

nonisolated private let mlsEspnTeamIds: [String: String] = [
    "ATL": "18418", "ATX": "20906", "MTL": "9720", "CLT": "21300",
    "CHI": "182", "COL": "184", "CLB": "183", "DC": "193",
    "CIN": "18267", "DAL": "185", "HOU": "6077", "MIA": "20232",
    "LA": "187", "LAFC": "18966", "MIN": "17362", "NSH": "18986",
    "NE": "189", "NYC": "17606", "ORL": "12011", "PHI": "10739",
    "POR": "9723", "RSL": "4771", "RBNY": "190", "SD": "22529",
    "SJ": "191", "SEA": "9726", "SKC": "186", "STL": "21812",
    "TOR": "7318", "VAN": "9727",
]

nonisolated class SportsDataService: @unchecked Sendable {
    static let shared = SportsDataService()

    private let hardcodedAPIKey = "9b42211a91c1440795cd6217baa9e334"

    nonisolated func fetchSchedule(leagueId: String, teamAbbr: String, season: String) async throws -> [Game] {
        if leagueId == "mls" {
            return try await fetchMLSScheduleFromESPN(teamAbbr: teamAbbr, season: season)
        }

        let apiKey = hardcodedAPIKey
        guard !apiKey.isEmpty else { throw ScheduleError.noAPIKey }
        guard let config = leagueConfigs[leagueId] else { throw ScheduleError.unsupportedLeague(leagueId) }

        var suffixes: [(String, GameType)] = []
        if config.hasPreseason {
            suffixes.append(("PRE", .preseason))
        }
        suffixes.append(("", .regular))
        suffixes.append(("POST", .playoff))

        var allGames: [Game] = []

        for (suffix, gameType) in suffixes {
            let seasonParam = season + suffix
            let urlString = "https://api.sportsdata.io/v3/\(config.basePath)/\(config.endpoint)/\(seasonParam)?key=\(apiKey)"
            guard let url = URL(string: urlString) else { continue }

            print("[SportsData] Fetching: \(config.endpoint)/\(seasonParam) for team=\(teamAbbr)")

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    print("[SportsData] HTTP \(code) for \(seasonParam), skipping")
                    continue
                }

                let sdGames = try JSONDecoder().decode([SDScheduleGame].self, from: data)
                let homeGames = sdGames.filter { $0.resolvedHomeTeam == teamAbbr }
                print("[SportsData] \(suffix.isEmpty ? "REG" : suffix): \(sdGames.count) total, \(homeGames.count) home games for \(teamAbbr)")

                if homeGames.isEmpty && !sdGames.isEmpty {
                    let allHomeTeams = Set(sdGames.map(\.resolvedHomeTeam)).sorted()
                    print("[SportsData] Available home teams: \(allHomeTeams.joined(separator: ", "))")
                }

                let mapped: [Game] = homeGames.compactMap { sdGame -> Game? in
                    guard let dateStr = sdGame.resolvedDateTime else { return nil }
                    guard let date = parseDate(dateStr) else { return nil }

                    let opponentAbbr = sdGame.resolvedAwayTeam
                    let opponentName = LeagueData.teamNameForAPIAbbr(opponentAbbr, leagueId: leagueId)

                    let timeStr: String
                    if sdGame.dateTime != nil || sdGame.dateField != nil {
                        timeStr = formatTime(dateStr)
                    } else {
                        timeStr = "TBD"
                    }

                    return Game(
                        id: sdGame.resolvedGameID,
                        date: date,
                        opponent: opponentName,
                        opponentAbbr: opponentAbbr,
                        venueName: "",
                        time: timeStr,
                        gameNumber: 0,
                        gameLabel: "",
                        type: gameType,
                        isHome: true
                    )
                }
                allGames.append(contentsOf: mapped)
            } catch {
                print("[SportsData] Error fetching \(seasonParam): \(error.localizedDescription)")
                continue
            }
        }

        var seen = Set<String>()
        allGames = allGames.filter { seen.insert($0.id).inserted }

        allGames.sort { $0.date < $1.date }

        var preCount = 0
        var regCount = 0
        var playoffCount = 0

        allGames = allGames.map { game in
            var g = game
            switch g.type {
            case .preseason:
                preCount += 1
                g.gameNumber = preCount
                g.gameLabel = "PS\(preCount)"
            case .regular:
                regCount += 1
                g.gameNumber = regCount
                g.gameLabel = "\(regCount)"
            case .playoff:
                playoffCount += 1
                g.gameNumber = playoffCount
                g.gameLabel = "P\(playoffCount)"
            }
            return g
        }

        if allGames.isEmpty {
            let regURL = "https://api.sportsdata.io/v3/\(config.basePath)/\(config.endpoint)/\(season)?key=\(apiKey)"
            if let url = URL(string: regURL) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let sdGames = try? JSONDecoder().decode([SDScheduleGame].self, from: data) {
                        let allTeams = Set(sdGames.map(\.resolvedHomeTeam)).sorted()
                        throw ScheduleError.noHomeGames("\(teamAbbr) (available: \(allTeams.joined(separator: ", ")))")
                    }
                } catch let e as ScheduleError {
                    throw e
                } catch {}
            }
            throw ScheduleError.noHomeGames(teamAbbr)
        }

        print("[SportsData] Total: \(allGames.count) games (pre:\(preCount) reg:\(regCount) post:\(playoffCount))")
        return allGames
    }

    private nonisolated func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: str) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "America/New_York")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: str)
    }

    private nonisolated func formatTime(_ str: String) -> String {
        guard let date = parseDate(str) else { return "TBD" }
        let df = DateFormatter()
        df.dateFormat = "h:mm a zzz"
        df.timeZone = TimezoneHelper.est
        return df.string(from: date)
    }

    private nonisolated func fetchMLSScheduleFromESPN(teamAbbr: String, season: String) async throws -> [Game] {
        guard mlsEspnTeamIds[teamAbbr] != nil else {
            let available = mlsEspnTeamIds.keys.sorted().joined(separator: ", ")
            throw ScheduleError.noHomeGames("\(teamAbbr) (available MLS teams: \(available))")
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        var seasonsToTry = [season]
        if season != "\(currentYear)" {
            seasonsToTry.append("\(currentYear)")
        }

        for seasonAttempt in seasonsToTry {
            print("[ESPN-MLS] Fetching season \(seasonAttempt) via date-range scoreboard")

            let dateRange = try await fetchMLSSeasonDateRange(season: seasonAttempt)
            guard let dateRange else {
                print("[ESPN-MLS] No calendar data for season \(seasonAttempt)")
                continue
            }

            print("[ESPN-MLS] Date range: \(dateRange.start)-\(dateRange.end)")

            let allEvents = try await fetchMLSScoreboardDateRange(start: dateRange.start, end: dateRange.end)
            print("[ESPN-MLS] Total events: \(allEvents.count)")

            let homeGames: [Game] = allEvents.compactMap { event in
                guard let competition = event.competitions.first else { return nil }
                let homeCompetitor = competition.competitors.first { $0.homeAway == "home" }
                let awayCompetitor = competition.competitors.first { $0.homeAway == "away" }

                guard let home = homeCompetitor, home.team.abbreviation == teamAbbr else { return nil }
                guard let away = awayCompetitor else { return nil }

                guard let date = parseESPNDate(event.date) else {
                    print("[ESPN-MLS] Failed to parse date: \(event.date)")
                    return nil
                }

                let opponentAbbr = away.team.abbreviation
                let opponentName = LeagueData.teamNameForAPIAbbr(opponentAbbr, leagueId: "mls")
                let venueName = competition.venue?.fullName ?? ""
                let timeStr = formatTime(from: date)

                let seasonTypeName = event.seasonType?.name?.lowercased() ?? "regular season"
                let gameType: GameType
                if seasonTypeName.contains("pre") {
                    gameType = .preseason
                } else if seasonTypeName.contains("post") || seasonTypeName.contains("playoff") || seasonTypeName.contains("cup") {
                    gameType = .playoff
                } else {
                    gameType = .regular
                }

                return Game(
                    id: event.id,
                    date: date,
                    opponent: opponentName,
                    opponentAbbr: opponentAbbr,
                    venueName: venueName,
                    time: timeStr,
                    gameNumber: 0,
                    gameLabel: "",
                    type: gameType,
                    isHome: true
                )
            }

            print("[ESPN-MLS] \(homeGames.count) home games for \(teamAbbr) in season \(seasonAttempt)")

            if homeGames.isEmpty { continue }

            var allGames = homeGames.sorted { $0.date < $1.date }

            var seen = Set<String>()
            allGames = allGames.filter { seen.insert($0.id).inserted }

            var regCount = 0
            var preCount = 0
            var playoffCount = 0
            allGames = allGames.map { game in
                var g = game
                switch g.type {
                case .preseason:
                    preCount += 1
                    g.gameNumber = preCount
                    g.gameLabel = "PS\(preCount)"
                case .regular:
                    regCount += 1
                    g.gameNumber = regCount
                    g.gameLabel = "\(regCount)"
                case .playoff:
                    playoffCount += 1
                    g.gameNumber = playoffCount
                    g.gameLabel = "P\(playoffCount)"
                }
                return g
            }

            return allGames
        }

        throw ScheduleError.noHomeGames(teamAbbr)
    }

    private nonisolated func fetchMLSSeasonDateRange(season: String) async throws -> (start: String, end: String)? {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/scoreboard?dates=\(season)0101&limit=1"
        guard let url = URL(string: urlString) else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

        let scoreboard = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: data)
        guard let calendarStrings = scoreboard.leagues?.first?.calendar, calendarStrings.count >= 2 else { return nil }

        let outputFmt = DateFormatter()
        outputFmt.locale = Locale(identifier: "en_US_POSIX")
        outputFmt.dateFormat = "yyyyMMdd"
        outputFmt.timeZone = TimeZone(identifier: "UTC")

        var earliest: Date?
        var latest: Date?
        for calStr in calendarStrings {
            if let date = parseESPNDate(calStr) {
                if earliest == nil || date < earliest! { earliest = date }
                if latest == nil || date > latest! { latest = date }
            }
        }

        guard let start = earliest, let end = latest else { return nil }
        return (outputFmt.string(from: start), outputFmt.string(from: end))
    }

    private nonisolated func fetchMLSScoreboardDateRange(start: String, end: String) async throws -> [ESPNEvent] {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/scoreboard?dates=\(start)-\(end)&limit=900"
        guard let url = URL(string: urlString) else { return [] }

        print("[ESPN-MLS] Fetching: \(urlString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("[ESPN-MLS] HTTP \(code) for date-range scoreboard")
                return []
            }
            let scoreboard = try JSONDecoder().decode(ESPNScoreboardResponse.self, from: data)
            return scoreboard.events ?? []
        } catch {
            print("[ESPN-MLS] Error fetching date-range scoreboard: \(error.localizedDescription)")
            return []
        }
    }

    private nonisolated func parseESPNDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let d = formatter.date(from: str) { return d }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: str) { return d }

        let withSeconds = str.replacingOccurrences(
            of: #"(\d{2}:\d{2})Z"#,
            with: "$1:00Z",
            options: .regularExpression
        )
        if withSeconds != str {
            formatter.formatOptions = [.withInternetDateTime]
            if let d = formatter.date(from: withSeconds) { return d }
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm'Z'"] {
            df.dateFormat = fmt
            if let d = df.date(from: str) { return d }
        }

        return nil
    }

    private nonisolated func formatTime(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a zzz"
        df.timeZone = TimezoneHelper.est
        return df.string(from: date)
    }

    nonisolated func seasonString(for leagueId: String, from seasonLabel: String) -> String {
        let parts = seasonLabel.split(separator: "-")

        guard parts.count == 2, let startYear = Int(parts[0]) else {
            let digits = seasonLabel.filter { $0.isNumber }
            if digits.count >= 4 { return String(digits.prefix(4)) }
            return "\(Calendar.current.component(.year, from: Date()))"
        }

        let secondPart = String(parts[1])
        let endYear: Int
        if secondPart.count == 2, let short = Int(secondPart) {
            endYear = (startYear / 100) * 100 + short
        } else if let full = Int(secondPart) {
            endYear = full
        } else {
            return "\(startYear)"
        }

        switch leagueId {
        case "nfl", "mls":
            return "\(startYear)"
        default:
            return "\(endYear)"
        }
    }
}
