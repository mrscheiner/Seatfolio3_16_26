import SwiftUI

nonisolated enum LogoSource: String, Sendable {
    case localById = "local-by-id"
    case localByAbbreviation = "local-by-abbreviation"
    case localByName = "local-by-name"
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

    func resolve(teamId: String? = nil, abbreviation: String? = nil, apiAbbr: String? = nil, teamName: String? = nil, leagueId: String? = nil) -> ResolvedLogo {
        if let teamId, !teamId.isEmpty {
            if let img = loadLocal(teamId) {
                log(teamId, source: .localById)
                return ResolvedLogo(image: img, source: .localById, remoteURL: nil)
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
