import SwiftUI
import MapKit

struct SignDetailView: View {
    let sign: ArtSign

    @Environment(ProgressStore.self) private var progress
    @Environment(LocationService.self) private var location
    @Environment(PhotoStore.self) private var photoStore
    @Environment(\.openURL) private var openURL

    @State private var confirmManual = false
    @State private var celebrate = false
    @State private var showCamera = false
    @State private var celebrateAfterCamera = false
    @State private var stampTrigger = 0
    @State private var pendingStamp = false
    @State private var showOfficialPage = false

    private var visited: Bool { progress.isVisited(sign) }
    private var near: Bool { location.isNear(sign) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                checkInCard
                SignPhotosSection(sign: sign) { showCamera = true }
                conceptSection
                motifSection
                actions
                Text("作品画像は公式に公開されていないため、本アプリには掲載していません。ぜひ現地でご覧ください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                // 写真を撮り終えたらスタンプを押す
                guard pendingStamp else { return }
                pendingStamp = false
                pressStampThenCelebrate()
            }) {
                CameraPicker { image in
                    photoStore.add(image, for: sign)
                }
                .ignoresSafeArea()
            }
        }
        .navigationTitle(sign.shortPlace)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: visited)
        .confirmationDialog("現地で鑑賞しましたか？", isPresented: $confirmManual, titleVisibility: .visible) {
            Button("鑑賞済みにする") { record() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("位置情報で到着を確認できない場合に使います。")
        }
        .sheet(isPresented: $showOfficialPage) {
            SafariView(url: sign.officialURL).ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $celebrate) {
            CompletionView { celebrate = false }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: sign.stampSymbol)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.color(for: sign.area).opacity(0.15), in: Capsule())
                    .foregroundStyle(Theme.color(for: sign.area))
                Text(sign.area.rawValue + "エリア")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(sign.title)
                .font(.system(.largeTitle, design: .serif).bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(sign.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label(sign.place, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
        }
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if visited, let date = progress.visitedDate(sign) {
                HStack(spacing: 16) {
                    StampView(sign: sign, date: date, size: 96)
                        .modifier(StampPress(trigger: stampTrigger))
                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text("鑑賞済み")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                        }
                        .font(.headline)
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("記録を取り消す", role: .destructive) { progress.unmark(sign) }
                            .font(.footnote)
                    }
                }
            } else {
                if let d = location.distance(to: sign) {
                    Text(near ? "アートサインの近くにいます" : "ここから \(d.walkText)（\(d.walkMinutesText)）")
                        .font(.subheadline)
                        .foregroundStyle(near ? Theme.accent : .secondary)
                }
                Button {
                    if near { record() } else { confirmManual = true }
                } label: {
                    Label("見た！を記録する", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if CameraPicker.isAvailable {
                    Label("記録すると、そのまま記念の写真を撮れます", systemImage: "camera")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("ポイントを貯めるには、サインの二次元コードを区の健幸アプリ「なみチャレ」で読み取ってください（本アプリの記録はポイント対象外です）。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.sky, in: RoundedRectangle(cornerRadius: 16))
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("作品について").font(.title3.bold())
            Text(sign.summary)
                .font(.body)
                .lineSpacing(4)
        }
    }

    private var motifSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("現地で探してみよう").font(.title3.bold())
            ForEach(sign.motifs, id: \.self) { m in
                Label(m, systemImage: "magnifyingglass")
                    .font(.subheadline)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            DirectionsMenu(name: "\(sign.place)（アートサイン）", coordinate: sign.coordinate) {
                Label("マップで徒歩経路を開く", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                // アプリの中で区のページを開く（Safariに切り替えない）
                showOfficialPage = true
            } label: {
                Label("区の公式ページで全文を読む", systemImage: "doc.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            ShareLink(item: sign.officialURL,
                      message: Text("すぎなみアートウォーク「\(sign.title)」（\(sign.place)）")) {
                Label("共有", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func record() {
        progress.markVisited(sign)
        celebrateAfterCamera = progress.isComplete
        if CameraPicker.isAvailable {
            // 先に写真を撮り、閉じたらスタンプ → コンプリート画面
            pendingStamp = true
            showCamera = true
        } else {
            pressStampThenCelebrate()
        }
    }

    private func pressStampThenCelebrate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            stampTrigger += 1
        }
        if celebrateAfterCamera {
            celebrateAfterCamera = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                celebrate = true
            }
        }
    }
}
