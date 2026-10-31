import SwiftUI

/// コンプリート時の歩いた記録の集計
struct CompletionStats {
    var distance: Double
    var duration: TimeInterval
    var steps: Int?
    var kcal: Double
    /// 記録中（まだ続いている）かどうか
    var isLive: Bool
}

/// 7か所コンプリート画面（記念写真・歩いた記録・共有）
struct CompletionView: View {
    var onClose: () -> Void

    @Environment(ProgressStore.self) private var progress
    @Environment(PhotoStore.self) private var photos
    @Environment(WalkRecorder.self) private var recorder
    @Environment(WalkHistoryStore.self) private var history
    @Environment(LocationService.self) private var location
    @AppStorage(Calorie.weightKey) private var weightKg: Double = Calorie.defaultWeightKg

    @State private var bounce = false
    @State private var summaryRecord: WalkRecord?
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    ConstellationView(animated: true, height: 230)
                    photoGrid
                    statsSection
                    Text("阿佐谷・高円寺のアートサインをすべて巡りました。\nおつかれさまでした。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    buttons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                LinearGradient(colors: [Theme.sky, Color(.systemBackground)], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onClose)
                }
                ToolbarItem(placement: .primaryAction) {
                    if let shareImage {
                        let image = Image(uiImage: shareImage)
                        ShareLink(item: image,
                                  preview: SharePreview("すぎなみアートウオーク 7か所コンプリート", image: image)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("記録を画像で共有")
                    }
                }
            }
            .sheet(item: $summaryRecord) { record in
                NavigationStack { WalkSummaryView(record: record, showsCloseButton: true) }
            }
            .task(id: recorder.isRecording) { renderShareImage() }
        }
    }

    // MARK: 部品

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(Theme.star)
                .symbolEffect(.bounce, options: .repeat(2), value: bounce)
                .onAppear { bounce = true }
            Text("7か所コンプリート！")
                .font(.largeTitle.bold())
            if let date = progress.completedDate {
                Text(date.formatted(.dateTime.year().month().day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 7か所の記念写真（撮っていない場所は場所アイコンのタイル）＋コンプリートのタイル
    private var photoGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(ArtSign.all) { sign in
                if let photo = photos.photos(for: sign).first {
                    PhotoThumb(photo: photo)
                        .overlay(alignment: .topLeading) {
                            Image(systemName: sign.stampSymbol)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Theme.color(for: sign.area)))
                                .padding(4)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.color(for: sign.area).opacity(0.15))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            VStack(spacing: 4) {
                                SignPin(sign: sign, visited: true).scaleEffect(0.75)
                                Text(sign.shortPlace)
                                    .font(.system(size: 9))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 2)
                            }
                        }
                }
            }
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [Theme.asagaya, Theme.route, Theme.koenji],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 0) {
                        Text("7/7").font(.title3.bold())
                        Text("達成").font(.caption2.bold())
                    }
                    .foregroundStyle(.white)
                }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats = currentStats {
            VStack(alignment: .leading, spacing: 10) {
                Text(stats.isLive ? "ここまでの歩いた記録（記録中）" : "歩いた記録")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath",
                             title: "歩いた距離", value: stats.distance.walkText)
                    StatTile(icon: "flame", title: "消費カロリー（目安）",
                             value: "\(Int(stats.kcal.rounded())) kcal")
                    StatTile(icon: "figure.walk", title: "歩数",
                             value: stats.steps.map { "\($0.formatted()) 歩" } ?? "—")
                    StatTile(icon: "clock", title: "時間", value: stats.duration.walkDurationText)
                }
            }
        } else {
            Label("「スタート」を押して歩くと、距離や消費カロリーもここに残せます。", systemImage: "figure.walk")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.sky, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            if recorder.isRecording {
                Button {
                    guard let record = recorder.stop(location: location, progress: progress) else { return }
                    if record.distance >= 20 || record.duration >= 60 { history.add(record) }
                    summaryRecord = record
                } label: {
                    Label("記録を停止してまとめを見る", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Button(action: onClose) {
                Text("閉じる").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: 集計

    /// 記録中ならその時点まで、そうでなければ「1か所目〜コンプリート」と重なる保存済みの記録の合計
    private var currentStats: CompletionStats? {
        if recorder.isRecording {
            return CompletionStats(
                distance: recorder.distance,
                duration: recorder.elapsed(),
                steps: recorder.steps,
                kcal: Calorie.kcal(weightKg: weightKg, movingTime: recorder.movingTime, distance: recorder.distance),
                isLive: true)
        }
        guard let first = progress.firstVisitDate, let done = progress.completedDate else { return nil }
        let records = history.records.filter { $0.end >= first && $0.start <= done }
        guard !records.isEmpty else { return nil }
        let steps = records.compactMap(\.steps)
        return CompletionStats(
            distance: records.reduce(0) { $0 + $1.distance },
            duration: records.reduce(0) { $0 + $1.duration },
            steps: steps.isEmpty ? nil : steps.reduce(0, +),
            kcal: records.reduce(0) { $0 + $1.kcal(weightKg: weightKg) },
            isLive: false)
    }

    @MainActor
    private func renderShareImage() {
        let card = CompletionShareCard(date: progress.completedDate ?? Date(), stats: currentStats)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareImage = renderer.uiImage
    }
}

/// 共有用の画像（作品の写真は含めない）
struct CompletionShareCard: View {
    let date: Date
    let stats: CompletionStats?

    var body: some View {
        VStack(spacing: 18) {
            Text("すぎなみアートウオーク")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.accent)
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.star)
            Text("7か所コンプリート！")
                .font(.system(size: 30, weight: .heavy))
            HStack(spacing: 6) {
                ForEach(ArtSign.all) { sign in
                    SignPin(sign: sign, visited: true).scaleEffect(0.85)
                }
            }
            if let stats {
                HStack(spacing: 24) {
                    shareStat(stats.distance.walkText, "歩いた距離")
                    shareStat("\(Int(stats.kcal.rounded())) kcal", "消費カロリー")
                    if let steps = stats.steps { shareStat(steps.formatted(), "歩数") }
                }
            }
            Text("阿佐谷・高円寺 \(date.formatted(.dateTime.year().month().day()))")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("すぎなみアートウオークアプリ(非公式)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 360, height: 450)
        .background(
            LinearGradient(colors: [Color(red: 0.75, green: 0.91, blue: 0.93), .white],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func shareStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}
