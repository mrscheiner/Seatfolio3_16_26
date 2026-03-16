import SwiftUI

struct TeamLogoView: View {
    let teamId: String
    let abbreviation: String
    let apiAbbr: String
    let teamName: String
    let leagueId: String
    let size: CGFloat

    init(
        teamId: String = "",
        abbreviation: String = "",
        apiAbbr: String = "",
        teamName: String = "",
        leagueId: String = "",
        size: CGFloat = 40
    ) {
        self.teamId = teamId
        self.abbreviation = abbreviation
        self.apiAbbr = apiAbbr
        self.teamName = teamName
        self.leagueId = leagueId
        self.size = size
    }

    private var resolved: ResolvedLogo {
        LocalLogoResolver.shared.resolve(
            teamId: teamId,
            abbreviation: abbreviation,
            apiAbbr: apiAbbr,
            teamName: teamName,
            leagueId: leagueId
        )
    }

    var body: some View {
        let logo = resolved
        Group {
            if let uiImage = logo.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let remote = logo.remoteURL, let url = URL(string: remote) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    case .failure:
                        fallbackCircle
                    default:
                        ProgressView()
                            .frame(width: size * 0.5, height: size * 0.5)
                    }
                }
            } else {
                fallbackCircle
            }
        }
        .frame(width: size, height: size)
    }

    private var fallbackCircle: some View {
        Circle().fill(Color(.tertiarySystemFill))
            .overlay {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
    }
}

struct LeagueLogoView: View {
    let leagueId: String
    let size: CGFloat

    init(leagueId: String, size: CGFloat = 100) {
        self.leagueId = leagueId
        self.size = size
    }

    private var resolved: ResolvedLogo {
        LocalLogoResolver.shared.resolveLeague(leagueId)
    }

    var body: some View {
        let logo = resolved
        Group {
            if let uiImage = logo.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let remote = logo.remoteURL, let url = URL(string: remote) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        Image(systemName: "sportscourt.fill")
                            .font(.system(size: size * 0.48))
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                    }
                }
            } else {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: size * 0.48))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
