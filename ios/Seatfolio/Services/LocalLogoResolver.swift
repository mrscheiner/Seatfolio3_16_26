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

    private let espnToLocal: [String: String] = [
        "nhl/ana": "ana", "nhl/bos": "bos", "nhl/buf": "buf", "nhl/cgy": "cgy",
        "nhl/car": "car", "nhl/chi": "chi", "nhl/col": "col", "nhl/cbj": "cbj",
        "nhl/dal": "dal", "nhl/det": "det", "nhl/edm": "edm", "nhl/fla": "fla",
        "nhl/lak": "lak", "nhl/min": "min", "nhl/mtl": "mtl", "nhl/nsh": "nsh",
        "nhl/njd": "njd", "nhl/nyi": "nyi", "nhl/nyr": "nyr", "nhl/ott": "ott",
        "nhl/phi": "phi", "nhl/pit": "pit", "nhl/sj": "sjs", "nhl/sea": "sea",
        "nhl/stl": "stl", "nhl/tb": "tbl", "nhl/tor": "tor", "nhl/van": "van",
        "nhl/vgk": "vgk", "nhl/wsh": "wsh", "nhl/wpg": "wpg", "nhl/uta": "uta",

        "nba/atl": "atl", "nba/bkn": "bkn", "nba/bos": "bos_nba", "nba/cha": "cha",
        "nba/chi": "chi_nba", "nba/cle": "cle", "nba/dal": "dal_nba", "nba/den": "den",
        "nba/det": "det_nba", "nba/gsw": "gsw", "nba/hou": "hou", "nba/ind": "ind",
        "nba/lac": "lac", "nba/lal": "lal", "nba/mem": "mem", "nba/mia": "mia",
        "nba/mil": "mil", "nba/min": "min_nba", "nba/nop": "nop", "nba/nyk": "nyk",
        "nba/okc": "okc", "nba/orl": "orl", "nba/phi": "phi_nba", "nba/phx": "phx",
        "nba/por": "por", "nba/sac": "sac", "nba/sas": "sas", "nba/tor": "tor_nba",
        "nba/uta": "uta_nba", "nba/wsh": "was",

        "nfl/ari": "ari", "nfl/atl": "atl_nfl", "nfl/bal": "bal", "nfl/buf": "buf_nfl",
        "nfl/car": "car_nfl", "nfl/chi": "chi_nfl", "nfl/cin": "cin", "nfl/cle": "cle_nfl",
        "nfl/dal": "dal_nfl", "nfl/den": "den_nfl", "nfl/det": "det_nfl", "nfl/gb": "gb",
        "nfl/hou": "hou_nfl", "nfl/ind": "ind_nfl", "nfl/jax": "jax", "nfl/kc": "kc",
        "nfl/lv": "lv", "nfl/lac": "lac_nfl", "nfl/lar": "lar", "nfl/mia": "mia_nfl",
        "nfl/min": "min_nfl", "nfl/ne": "ne", "nfl/no": "no", "nfl/nyg": "nyg",
        "nfl/nyj": "nyj", "nfl/phi": "phi_nfl", "nfl/pit": "pit_nfl", "nfl/sf": "sf",
        "nfl/sea": "sea_nfl", "nfl/tb": "tb", "nfl/ten": "ten", "nfl/wsh": "was_nfl",

        "mlb/ari": "ari_mlb", "mlb/atl": "atl_mlb", "mlb/bal": "bal_mlb", "mlb/bos": "bos_mlb",
        "mlb/chc": "chc", "mlb/chw": "cws", "mlb/cin": "cin_mlb", "mlb/cle": "cle_mlb",
        "mlb/col": "col_mlb", "mlb/det": "det_mlb", "mlb/hou": "hou_mlb", "mlb/kc": "kc_mlb",
        "mlb/laa": "laa", "mlb/lad": "lad", "mlb/mil": "mil_mlb", "mlb/min": "min_mlb",
        "mlb/nym": "nym", "mlb/nyy": "nyy", "mlb/ath": "oak", "mlb/phi": "phi_mlb",
        "mlb/pit": "pit_mlb", "mlb/sd": "sd", "mlb/sf": "sf_mlb", "mlb/sea": "sea_mlb",
        "mlb/stl": "stl_mlb", "mlb/tb": "tb_mlb", "mlb/tex": "tex", "mlb/tor": "tor_mlb",
        "mlb/wsh": "was_mlb",

        "mls/atl": "atl_mls", "mls/aus": "aus", "mls/chi": "chi_mls", "mls/cin": "cin_mls",
        "mls/clt": "cha_mls", "mls/col": "col_mls", "mls/columbus": "clb", "mls/dal": "dal_mls",
        "mls/dc": "dc", "mls/hou": "hou_mls", "mls/kc": "skc", "mls/la": "lag",
        "mls/lafc": "lafc", "mls/mia": "inter", "mls/mtl": "mtl_mls", "mls/nashville": "nsh_mls",
        "mls/ne": "ne_mls", "mls/ny": "nyrb", "mls/nyc": "nyc", "mls/orl": "orl_mls",
        "mls/phi": "phi_mls", "mls/por": "por_mls", "mls/rsl": "rsl", "mls/sea": "sea_mls",
        "mls/sj": "sj_mls", "mls/stl": "stl_mls", "mls/tor": "tor_mls", "mls/van": "van_mls",
    ]

    private let apiAbbrAliases: [String: [String]] = [
        "nhl": [
            "MON:mtl", "NAS:nsh", "VEG:vgk", "WAS:wsh", "TB:tbl", "SJ:sjs", "LA:lak",
            "MTL:mtl", "NSH:nsh", "VGK:vgk", "WSH:wsh", "TBL:tbl", "SJS:sjs", "LAK:lak",
        ],
        "nba": [
            "GS:gsw", "NO:nop", "NY:nyk", "SA:sas", "PHO:phx", "WAS:was",
            "GSW:gsw", "NOP:nop", "NYK:nyk", "SAS:sas", "PHX:phx", "WSH:was",
        ],
        "nfl": [
            "LAR:lar", "LV:lv", "GB:gb", "TB:tb", "JAX:jax", "NE:ne", "NO:no",
            "NYG:nyg", "NYJ:nyj", "SF:sf", "KC:kc", "WAS:was_nfl", "WSH:was_nfl",
        ],
        "mlb": [
            "CHC:chc", "CWS:cws", "CHW:cws", "LAA:laa", "LAD:lad", "NYM:nym",
            "NYY:nyy", "OAK:oak", "ATH:oak", "SD:sd", "TEX:tex", "TB:tb_mlb",
            "WAS:was_mlb", "WSH:was_mlb",
        ],
        "mls": [
            "ATX:aus", "CLB:clb", "LAFC:lafc", "LAG:lag", "NYRB:nyrb", "NYC:nyc",
            "SKC:skc", "RSL:rsl", "DC:dc", "CLT:cha_mls", "NSH:nsh_mls", "SJ:sj_mls",
        ],
    ]

    func resolve(teamId: String? = nil, abbreviation: String? = nil, apiAbbr: String? = nil, teamName: String? = nil, leagueId: String? = nil) -> ResolvedLogo {
        if let teamId, !teamId.isEmpty {
            if let img = loadLocal(teamId) {
                log(teamId, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
            }
        }

        if let lid = leagueId, !lid.isEmpty {
            if let apiAbbr, !apiAbbr.isEmpty {
                let espnKey = "\(lid)/\(apiAbbr.lowercased())"
                if let localName = espnToLocal[espnKey], let img = loadLocal(localName) {
                    log("\(espnKey)→\(localName)", source: .localByAlias)
                    return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
                }

                if let aliases = apiAbbrAliases[lid] {
                    let upper = apiAbbr.uppercased()
                    for alias in aliases {
                        let parts = alias.split(separator: ":")
                        if parts.count == 2, String(parts[0]) == upper {
                            let localName = String(parts[1])
                            if let img = loadLocal(localName) {
                                log("\(upper)→\(localName)", source: .localByAlias)
                                return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
                            }
                        }
                    }
                }
            }

            if let abbreviation, !abbreviation.isEmpty {
                let espnKey = "\(lid)/\(abbreviation.lowercased())"
                if let localName = espnToLocal[espnKey], let img = loadLocal(localName) {
                    log("\(espnKey)→\(localName)", source: .localByAlias)
                    return ResolvedLogo(image: img, source: .localByAlias, remoteURL: nil)
                }
            }
        }

        if let team = findTeam(teamId: teamId, abbreviation: abbreviation, apiAbbr: apiAbbr, teamName: teamName, leagueId: leagueId) {
            if let img = loadLocal(team.id) {
                log(team.id, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
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

        log(teamId ?? abbreviation ?? teamName ?? "unknown", source: .none)
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
        let key = "\(league)/\(espnId)"
        if let localName = espnToLocal[key], let img = loadLocal(localName) {
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
        }

        if let abbreviation, !abbreviation.isEmpty {
            let upper = abbreviation.uppercased()
            if let lid = leagueId, let league = LeagueData.league(for: lid) {
                if let team = league.teams.first(where: { $0.abbreviation == upper }) {
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
            for league in LeagueData.allLeagues {
                if let team = league.teams.first(where: {
                    lowered.contains($0.name.lowercased()) ||
                    lowered.contains($0.city.lowercased()) ||
                    $0.name.lowercased().contains(lowered) ||
                    "\($0.city) \($0.name)".lowercased() == lowered ||
                    "\($0.city) \($0.name)".lowercased().contains(lowered) ||
                    lowered.contains("\($0.city) \($0.name)".lowercased())
                }) {
                    return team
                }
            }
        }

        return nil
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
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "TeamLogos") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
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
