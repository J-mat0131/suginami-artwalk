import SwiftUI

struct SignListView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(LocationService.self) private var location
    @Environment(RouteService.self) private var route
    @Environment(PhotoStore.self) private var photos
    @State private var showCompletion = false
    @Environment(AchievementStore.self) private var achievements

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
                            Text("好きな順番で巡れます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    if progress.isComplete {
                        Button { showCompletion = true } label: {
                            Label("コンプリート画面を見る", systemImage: "star.circle.fill")
                        }
                    }
                }

                Section("あそぶ") {
                    NavigationLink { StampBookView() } label: {
                        HStack {
                            Label("スタンプ帳", systemImage: "seal")
                            Spacer()
                            Text("\(progress.visitedCount)/\(progress.total)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { AchievementsView() } label: {
                        HStack {
                            Label("称号", systemImage: "rosette")
                            if !achievements.unseen.isEmpty {
                                Text("NEW")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.red))
                            }
                            Spacer()
                            Text("\(achievements.count)/\(Achievements.all.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { ConstellationScreen() } label: {
                        Label("すぎなみ座", systemImage: "sparkles")
                    }
                }

                if !photos.photos.isEmpty {
                    Section { RecentPhotosStrip() }
                }

                Section("アートサイン") {
                    ForEach(ArtSign.all) { sign in
                        NavigationLink(value: sign) {
                            SignRow(sign: sign,
                                    visited: progress.isVisited(sign),
                                    photoCount: photos.photos(for: sign).count,
                                    distance: location.distance(to: sign))
                        }
                    }
                }
            }
            .navigationTitle("アート")
            .navigationDestination(for: ArtSign.self) { SignDetailView(sign: $0) }
            .fullScreenCover(isPresented: $showCompletion) {
                CompletionView { showCompletion = false }
            }
        }
    }
}

private struct SignRow: View {
    let sign: ArtSign
    let visited: Bool
    let photoCount: Int
    let distance: Double?

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
                    if photoCount > 0 {
                        Label("\(photoCount)", systemImage: "camera.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
