import SwiftUI

struct SignListView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(LocationService.self) private var location
    @Environment(RouteService.self) private var route

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ProgressRing(fraction: progress.fraction, lineWidth: 8)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text("\(progress.visitedCount)/\(progress.total)")
                                    .font(.subheadline.bold().monospacedDigit())
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(progress.isComplete ? "全サイン鑑賞おめでとうございます！" : "アートサインを巡ろう")
                                .font(.headline)
                            Text("阿佐ケ谷駅から反時計回りの順に並んでいます。順番は自由にアレンジできます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("アートサイン") {
                    ForEach(ArtSign.all) { sign in
                        NavigationLink(value: sign) {
                            SignRow(sign: sign,
                                    visited: progress.isVisited(sign),
                                    distance: location.distance(to: sign),
                                    legToNext: route.legs.first { $0.id == sign.id })
                        }
                    }
                }
            }
            .navigationTitle("アート")
            .navigationDestination(for: ArtSign.self) { SignDetailView(sign: $0) }
        }
    }
}

private struct SignRow: View {
    let sign: ArtSign
    let visited: Bool
    let distance: Double?
    let legToNext: RouteService.Leg?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SignPin(sign: sign, visited: visited)
            VStack(alignment: .leading, spacing: 4) {
                Text(sign.title).font(.headline)
                Text(sign.place).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label(sign.area.rawValue, systemImage: "mappin")
                        .foregroundStyle(Theme.color(for: sign.area))
                    if let d = distance {
                        Text("現在地から \(d.walkText)")
                    }
                }
                .font(.caption)
                if let leg = legToNext {
                    Text("次の地点まで \(leg.distance.walkText)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
