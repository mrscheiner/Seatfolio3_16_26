import SwiftUI

nonisolated enum LogoSource: String, Sendable {
    case localById = "local-by-id"
    case localByAbbreviation = "local-by-abbreviation"
    case localByName = "local-by-name"
    case localByAlias = "local-by-alias"
    case fallbackLeague = "fallback-league"
    case remoteURL = "remote-url"
    case none = "none"
}

struct ResolvedLogo: Sendable {
    let image: UIImage?
    let source: LogoSource
    let remoteURL: String?
}

nonisolated final class LocalLogoResolver: Sendable {
    static let shared = LocalLogoResolver()

    private let apiToLocal: [String: String] = [
        "nhl/ana": "ana", "nhl/bos": "bos", "nhl/buf": "buf", "nhl/cgy": "cgy",
        "nhl/car": "car", "nhl/chi": "chi", "nhl/col": "col", "nhl/cbj": "cbj",
        "nhl/dal": "dal", "nhl/det": "det", "nhl/edm": "edm", "nhl/fla": "fla",
        "nhl/la": "lak", "nhl/min": "min", "nhl/mon": "mtl", "nhl/nas": "nsh",
        "nhl/nj": "njd", "nhl/nyi": "nyi", "nhl/nyr": "nyr", "nhl/ott": "ott",
        "nhl/phi": "phi", "nhl/pit": "pit", "nhl/sj": "sjs", "nhl/sea": "sea",
        "nhl/stl": "stl", "nhl/tb": "tbl", "nhl/tor": "tor", "nhl/van": "van",
        "nhl/veg": "vgk", "nhl/was": "wsh", "nhl/wpg": "wpg", "nhl/uta": "uta",
        "nhl/lak": "lak", "nhl/mtl": "mtl", "nhl/nsh": "nsh", "nhl/njd": "njd",
        "nhl/sjs": "sjs", "nhl/tbl": "tbl", "nhl/vgk": "vgk", "nhl/wsh": "wsh",

        "nba/atl": "atl", "nba/bkn": "bkn", "nba/bos": "bos_nba", "nba/cha": "cha",
        "nba/chi": "chi_nba", "nba/cle": "cle", "nba/dal": "dal_nba", "nba/den": "den",
        "nba/det": "det_nba", "nba/gs": "gsw", "nba/hou": "hou", "nba/ind": "ind",
        "nba/lac": "lac", "nba/lal": "lal", "nba/mem": "mem", "nba/mia": "mia",
        "nba/mil": "mil", "nba/min": "min_nba", "nba/no": "nop", "nba/ny": "nyk",
        "nba/okc": "okc", "nba/orl": "orl", "nba/phi": "phi_nba", "nba/pho": "phx",
        "nba/por": "por", "nba/sac": "sac", "nba/sa": "sas", "nba/tor": "tor_nba",
        "nba/uta": "uta_nba", "nba/was": "was",
        "nba/gsw": "gsw", "nba/nop": "nop", "nba/nyk": "nyk", "nba/phx": "phx",
        "nba/sas": "sas", "nba/wsh": "was",

        "nfl/ari": "ari", "nfl/atl": "atl_nfl", "nfl/bal": "bal", "nfl/buf": "buf_nfl",
        "nfl/car": "car_nfl", "nfl/chi": "chi_nfl", "nfl/cin": "cin", "nfl/cle": "cle_nfl",
        "nfl/dal": "dal_nfl", "nfl/den": "den_nfl", "nfl/det": "det_nfl", "nfl/gb": "gb",
        "nfl/hou": "hou_nfl", "nfl/ind": "ind_nfl", "nfl/jax": "jax", "nfl/kc": "kc",
        "nfl/lv": "lv", "nfl/lac": "lac_nfl", "nfl/lar": "lar", "nfl/mia": "mia_nfl",
        "nfl/min": "min_nfl", "nfl/ne": "ne", "nfl/no": "no", "nfl/nyg": "nyg",
        "nfl/nyj": "nyj", "nfl/phi": "phi_nfl", "nfl/pit": "pit_nfl", "nfl/sf": "sf",
        "nfl/sea": "sea_nfl", "nfl/tb": "tb", "nfl/ten": "ten", "nfl/was": "was_nfl",
        "nfl/wsh": "was_nfl",

        "mlb/ari": "ari_mlb", "mlb/atl": "atl_mlb", "mlb/bal": "bal_mlb", "mlb/bos": "bos_mlb",
        "mlb/chc": "chc", "mlb/cws": "cws", "mlb/chw": "cws", "mlb/cin": "cin_mlb",
        "mlb/cle": "cle_mlb", "mlb/col": "col_mlb", "mlb/det": "det_mlb", "mlb/hou": "hou_mlb",
        "mlb/kc": "kc_mlb", "mlb/laa": "laa", "mlb/lad": "lad", "mlb/mil": "mil_mlb",
        "mlb/min": "min_mlb", "mlb/nym": "nym", "mlb/nyy": "nyy", "mlb/oak": "oak",
        "mlb/ath": "oak", "mlb/phi": "phi_mlb", "mlb/pit": "pit_mlb", "mlb/sd": "sd",
        "mlb/sf": "sf_mlb", "mlb/sea": "sea_mlb", "mlb/stl": "stl_mlb", "mlb/tb": "tb_mlb",
        "mlb/tex": "tex", "mlb/tor": "tor_mlb", "mlb/was": "was_mlb", "mlb/wsh": "was_mlb",

        "mls/atl": "atl_mls", "mls/atx": "aus", "mls/aus": "aus", "mls/clb": "clb",
        "mls/columbus": "clb", "mls/cin": "cin_mls", "mls/col": "col_mls", "mls/hou": "hou_mls",
        "mls/mia": "inter", "mls/lafc": "lafc", "mls/lag": "lag", "mls/la": "lag",
        "mls/min": "min_mls", "mls/mtl": "mtl_mls", "mls/nsh": "nsh_mls",
        "mls/nashville": "nsh_mls", "mls/ne": "ne_mls", "mls/nyc": "nyc", "mls/nyrb": "nyrb",
        "mls/ny": "nyrb", "mls/orl": "orl_mls", "mls/phi": "phi_mls", "mls/por": "por_mls",
        "mls/rsl": "rsl", "mls/sea": "sea_mls", "mls/skc": "skc", "mls/kc": "skc",
        "mls/sj": "sj_mls", "mls/stl": "stl_mls", "mls/tor": "tor_mls", "mls/van": "van_mls",
        "mls/dc": "dc", "mls/clt": "cha_mls", "mls/dal": "dal_mls", "mls/chi": "chi_mls",
    ]

    private let teamIdToLocal: [String: String] = [
        "ana": "ana", "bos": "bos", "buf": "buf", "cgy": "cgy", "car": "car",
        "chi": "chi", "col": "col", "cbj": "cbj", "dal": "dal", "det": "det",
        "edm": "edm", "fla": "fla", "lak": "lak", "min": "min", "mtl": "mtl",
        "nsh": "nsh", "njd": "njd", "nyi": "nyi", "nyr": "nyr", "ott": "ott",
        "phi": "phi", "pit": "pit", "sjs": "sjs", "sea": "sea", "stl": "stl",
        "tbl": "tbl", "tor": "tor", "van": "van", "vgk": "vgk", "wsh": "wsh",
        "wpg": "wpg", "uta": "uta",

        "atl": "atl", "bkn": "bkn", "bos_nba": "bos_nba", "cha": "cha",
        "chi_nba": "chi_nba", "cle": "cle", "dal_nba": "dal_nba", "den": "den",
        "det_nba": "det_nba", "gsw": "gsw", "hou": "hou", "ind": "ind",
        "lac": "lac", "lal": "lal", "mem": "mem", "mia": "mia", "mil": "mil",
        "min_nba": "min_nba", "nop": "nop", "nyk": "nyk", "okc": "okc",
        "orl": "orl", "phi_nba": "phi_nba", "phx": "phx", "por": "por",
        "sac": "sac", "sas": "sas", "tor_nba": "tor_nba", "uta_nba": "uta_nba",
        "was": "was",

        "ari": "ari", "atl_nfl": "atl_nfl", "bal": "bal", "buf_nfl": "buf_nfl",
        "car_nfl": "car_nfl", "chi_nfl": "chi_nfl", "cin": "cin", "cle_nfl": "cle_nfl",
        "dal_nfl": "dal_nfl", "den_nfl": "den_nfl", "det_nfl": "det_nfl", "gb": "gb",
        "hou_nfl": "hou_nfl", "ind_nfl": "ind_nfl", "jax": "jax", "kc": "kc",
        "lv": "lv", "lac_nfl": "lac_nfl", "lar": "lar", "mia_nfl": "mia_nfl",
        "min_nfl": "min_nfl", "ne": "ne", "no": "no", "nyg": "nyg", "nyj": "nyj",
        "phi_nfl": "phi_nfl", "pit_nfl": "pit_nfl", "sf": "sf", "sea_nfl": "sea_nfl",
        "tb": "tb", "ten": "ten", "was_nfl": "was_nfl",

        "ari_mlb": "ari_mlb", "atl_mlb": "atl_mlb", "bal_mlb": "bal_mlb",
        "bos_mlb": "bos_mlb", "chc": "chc", "cws": "cws", "cin_mlb": "cin_mlb",
        "cle_mlb": "cle_mlb", "col_mlb": "col_mlb", "det_mlb": "det_mlb",
        "hou_mlb": "hou_mlb", "kc_mlb": "kc_mlb", "laa": "laa", "lad": "lad",
        "mil_mlb": "mil_mlb", "min_mlb": "min_mlb", "nym": "nym", "nyy": "nyy",
        "oak": "oak", "phi_mlb": "phi_mlb", "pit_mlb": "pit_mlb", "sd": "sd",
        "sf_mlb": "sf_mlb", "sea_mlb": "sea_mlb", "stl_mlb": "stl_mlb",
        "tb_mlb": "tb_mlb", "tex": "tex", "tor_mlb": "tor_mlb", "was_mlb": "was_mlb",

        "atl_mls": "atl_mls", "aus": "aus", "clb": "clb", "cin_mls": "cin_mls",
        "col_mls": "col_mls", "hou_mls": "hou_mls", "inter": "inter", "lafc": "lafc",
        "lag": "lag", "min_mls": "min_mls", "mtl_mls": "mtl_mls", "nsh_mls": "nsh_mls",
        "ne_mls": "ne_mls", "nyc": "nyc", "nyrb": "nyrb", "orl_mls": "orl_mls",
        "phi_mls": "phi_mls", "por_mls": "por_mls", "rsl": "rsl", "sea_mls": "sea_mls",
        "skc": "skc", "sj_mls": "sj_mls", "stl_mls": "stl_mls", "tor_mls": "tor_mls",
        "van_mls": "van_mls", "dc": "dc", "cha_mls": "cha_mls", "dal_mls": "dal_mls",
        "chi_mls": "chi_mls",
    ]

    func resolve(teamId: String? = nil, abbreviation: String? = nil, apiAbbr: String? = nil, teamName: String? = nil, leagueId: String? = nil) -> ResolvedLogo {
        if let teamId, !teamId.isEmpty {
            if let localName = teamIdToLocal[teamId], let img = loadLocal(localName) {
                log(teamId, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
            }
            if let img = loadLocal(teamId) {
                log(teamId, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
            }
        }

        if let lid = leagueId, !lid.isEmpty {
            if let apiAbbr, !apiAbbr.isEmpty {
                let key = "\(lid)/\(apiAbbr.lowercased())"
                if let localName = apiToLocal[key], let img = loadLocal(localName) {
                    log("\(key)→\(localName)", source: .localByAlias)
                    return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
                }
            }

            if let abbreviation, !abbreviation.isEmpty {
                let key = "\(lid)/\(abbreviation.lowercased())"
                if let localName = apiToLocal[key], let img = loadLocal(localName) {
                    log("\(key)→\(localName)", source: .localByAbbreviation)
                    return ResolvedLogo(image: img, source: .localByAbbreviation, remoteURL: nil)
                }
            }
        }

        if let team = findTeam(teamId: teamId, abbreviation: abbreviation, apiAbbr: apiAbbr, teamName: teamName, leagueId: leagueId) {
            if let localName = teamIdToLocal[team.id], let img = loadLocal(localName) {
                log(team.id, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
            }
            if let img = loadLocal(team.id) {
                log(team.id, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
            }

            if let lid = leagueId ?? leagueIdForTeam(team) {
                let key = "\(lid)/\(team.apiAbbr.lowercased())"
                if let localName = apiToLocal[key], let img = loadLocal(localName) {
                    log("\(key)→\(localName)", source: .localByAlias)
                    return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
                }
            }

            let abbrKey = team.abbreviation.lowercased()
            if let img = loadLocal(abbrKey) {
                log(abbrKey, source: .localByAbbreviation)
                return ResolvedLogo(image: img, source: .localByAbbreviation, remoteURL: nil)
            }

            let nameKey = normalize(team.name)
            if let img = loadLocal(nameKey) {
                log(nameKey, source: .localByName)
                return ResolvedLogo(image: img, source: .localByName, remoteURL: nil)
            }

            if let lid = leagueId ?? leagueIdForTeam(team) {
                if let img = loadLocal("league_\(lid)") {
                    log("league_\(lid)", source: .fallbackLeague)
                    return ResolvedLogo(image: img, source: .fallbackLeague, remoteURL: team.logoURL)
                }
            }

            log(team.id, source: .remoteURL)
            return ResolvedLogo(image: nil, source: .remoteURL, remoteURL: team.logoURL)
        }

        if let apiAbbr, !apiAbbr.isEmpty {
            let lower = apiAbbr.lowercased()
            if let img = loadLocal(lower) {
                log(lower, source: .localByAbbreviation)
                return ResolvedLogo(image: img, source: .localByAbbreviation, remoteURL: nil)
            }
            for lid in ["nhl", "nba", "nfl", "mlb", "mls"] {
                let key = "\(lid)/\(lower)"
                if let localName = apiToLocal[key], let img = loadLocal(localName) {
                    log("\(key)→\(localName)", source: .localByAlias)
                    return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
                }
            }
        }

        if let abbreviation, !abbreviation.isEmpty {
            let lower = abbreviation.lowercased()
            if let img = loadLocal(lower) {
                log(lower, source: .localByAbbreviation)
                return ResolvedLogo(image: img, source: .localByAbbreviation, remoteURL: nil)
            }
        }

        if let lid = leagueId, !lid.isEmpty {
            if let img = loadLocal("league_\(lid)") {
                log("league_\(lid)", source: .fallbackLeague)
                return ResolvedLogo(image: img, source: .fallbackLeague, remoteURL: nil)
            }
        }

        log(teamId ?? abbreviation ?? apiAbbr ?? teamName ?? "unknown", source: .none)
        return ResolvedLogo(image: nil, source: .none, remoteURL: nil)
    }

    func resolveLeague(_ leagueId: String) -> ResolvedLogo {
        if let img = loadLocal("league_\(leagueId)") {
            log("league_\(leagueId)", source: .localById)
            return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
        }
        let remoteURL = LeagueData.league(for: leagueId)?.logoURL
        log("league_\(leagueId)", source: remoteURL != nil ? .remoteURL : .none)
        return ResolvedLogo(image: nil, source: remoteURL != nil ? .remoteURL : .none, remoteURL: remoteURL)
    }

    func resolveByESPNId(league: String, espnId: String) -> ResolvedLogo {
        let key = "\(league)/\(espnId.lowercased())"
        if let localName = apiToLocal[key], let img = loadLocal(localName) {
            log("\(key)→\(localName)", source: .localByAlias)
            return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
        }
        return resolve(abbreviation: espnId, leagueId: league)
    }

    private func findTeam(teamId: String?, abbreviation: String?, apiAbbr: String?, teamName: String?, leagueId: String?) -> Team? {
        if let teamId, !teamId.isEmpty, let team = LeagueData.team(for: teamId) {
            return team
        }

        if let apiAbbr, !apiAbbr.isEmpty {
            if let lid = leagueId, let team = LeagueData.teamByAPIAbbr(apiAbbr, leagueId: lid) {
                return team
            }
            for league in LeagueData.allLeagues {
                if let team = league.teams.first(where: { $0.apiAbbr == apiAbbr }) {
                    return team
                }
            }
            let upper = apiAbbr.uppercased()
            for league in LeagueData.allLeagues {
                if let team = league.teams.first(where: { $0.abbreviation == upper }) {
                    if leagueId == nil || league.id == leagueId {
                        return team
                    }
                }
            }
        }

        if let abbreviation, !abbreviation.isEmpty {
            let upper = abbreviation.uppercased()
            if let lid = leagueId, let league = LeagueData.league(for: lid) {
                if let team = league.teams.first(where: { $0.abbreviation == upper }) {
                    return team
                }
                if let team = league.teams.first(where: { $0.apiAbbr == upper || $0.apiAbbr == abbreviation }) {
                    return team
                }
            }
            for league in LeagueData.allLeagues {
                if let team = league.teams.first(where: { $0.abbreviation == upper }) {
                    return team
                }
            }
        }

        if let teamName, !teamName.isEmpty {
            let lowered = teamName.lowercased()
            if let lid = leagueId, let league = LeagueData.league(for: lid) {
                if let team = league.teams.first(where: { matchesTeam($0, query: lowered) }) {
                    return team
                }
            }
            for league in LeagueData.allLeagues {
                if let team = league.teams.first(where: { matchesTeam($0, query: lowered) }) {
                    return team
                }
            }
        }

        return nil
    }

    private func matchesTeam(_ team: Team, query: String) -> Bool {
        let fullName = "\(team.city) \(team.name)".lowercased()
        return query == fullName ||
            query.contains(team.name.lowercased()) ||
            team.name.lowercased().contains(query) ||
            fullName.contains(query) ||
            query.contains(fullName) ||
            query.contains(team.city.lowercased())
    }

    private func leagueIdForTeam(_ team: Team) -> String? {
        for league in LeagueData.allLeagues {
            if league.teams.contains(where: { $0.id == team.id }) {
                return league.id
            }
        }
        return nil
    }

    private func loadLocal(_ name: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "TeamLogos"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }

    private func normalize(_ input: String) -> String {
        input.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: "_")
    }

    private func log(_ key: String, source: LogoSource) {
        #if DEBUG
        print("[LogoResolver] \(key) → \(source.rawValue)")
        #endif
    }
}
