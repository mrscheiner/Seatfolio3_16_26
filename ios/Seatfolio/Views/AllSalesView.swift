import SwiftUI

struct AllSalesView: View {
    let sales: [Sale]
    let pass: SeasonPass?
    let theme: TeamTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sales) { sale in
                    RecentSaleCard(
                        sale: sale,
                        leagueId: pass?.leagueId ?? "",
                        games: pass?.games ?? [],
                        theme: theme
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All Sales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
