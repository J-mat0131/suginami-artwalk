import SwiftUI
import MapKit

/// 歩き終わった後のまとめ（距離・時間・歩数・消費カロリー・軌跡）
struct WalkSummaryView: View {
    let record: WalkRecord
    var showsCloseButton = false

    @Environment(\.dismiss) private var dismiss
    @AppStorage(Calorie.weightKey) private var weightKg: Double = Calorie.defaultWeightKg

    private var kcal: Double { record.kcal(weightKg: weightKg) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                trackMap
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.start.formatted(.dateTime.year().month().day().weekday()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(record.start.formatted(date: .omitted, time: .shortened)) 〜 \(record.end.formatted(date: .omitted, time: .shortened))")
                        .font(.headline)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath",
                             title: "歩いた距離", value: record.distance.walkText)
                    StatTile(icon: "flame", title: "消費カロリー（目安）",
                             value: "\(Int(kcal.rounded())) kcal")
                    StatTile(icon: "figure.walk", title: "歩数",
                             value: record.steps.map { "\($0.formatted()) 歩" } ?? "—")
                    StatTile(icon: "clock", title: record.pausedTime == nil ? "かかった時間" : "かかった時間（一時停止を除く）",
                             value: record.duration.walkDurationText)
                    StatTile(icon: "figure.walk.motion", title: "歩いていた時間",
                             value: record.movingTime.walkDurationText)
                    StatTile(icon: "speedometer", title: "平均の速さ",
                             value: record.averageSpeedKmh > 0 ? String(format: "%.1f km/h", record.averageSpeedKmh) : "—")
                }

                FunFactsView(distance: record.distance, kcal: kcal, steps: record.steps)

                if let paused = record.pausedTime, paused >= 1 {
                    Label("一時停止していた \(paused.walkDurationText) は、時間・歩数・距離に含めていません。", systemImage: "pause.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                visitedSection

                weightSection

                Text("消費カロリーは、歩いていた時間・平均の速さ・体重から求めた目安です（METs × 体重 × 時間 × 1.05）。立ち止まっていた時間は含めていません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle("歩いた記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: 部品

    @ViewBuilder
    private var trackMap: some View {
        if record.points.count >= 2 {
            Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
                ForEach(Array(record.segments.enumerated()), id: \.offset) { _, segment in
                    if segment.count >= 2 {
                        MapPolyline(coordinates: segment)
                            .stroke(Theme.track, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                }
                if let first = record.coordinates.first {
                    Annotation("スタート", coordinate: first, anchor: .center) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.asagaya))
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    .annotationTitles(.hidden)
                }
                if let last = record.coordinates.last {
                    Annotation("ゴール", coordinate: last, anchor: .center) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.track))
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(record.visitedSigns) { sign in
                    Annotation(sign.shortPlace, coordinate: sign.coordinate, anchor: .bottom) {
                        SignPin(sign: sign, visited: true)
                    }
                    .annotationTitles(.visible)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
        } else {
            ZStack {
                Theme.sky
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.largeTitle)
                    Text("軌跡を記録できませんでした").font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var visitedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("この記録中に見たアート").font(.title3.bold())
            if record.visitedSigns.isEmpty {
                Text("この間に「見た！」を記録したアートサインはありません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(record.visitedSigns) { sign in
                    HStack(spacing: 10) {
                        SignPin(sign: sign, visited: true).scaleEffect(0.8)
                        VStack(alignment: .leading) {
                            Text(sign.title).font(.subheadline.bold())
                            Text(sign.place).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カロリー計算の体重").font(.headline)
            Stepper(value: $weightKg, in: 30...150, step: 1) {
                Text("\(Int(weightKg)) kg").font(.body.monospacedDigit())
            }
            Text("体重は端末内にのみ保存され、ほかの記録の計算にも使われます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Theme.sky, in: RoundedRectangle(cornerRadius: 16))
    }

    private var shareText: String {
        var s = "すぎなみアートウォークを歩きました！\n"
        s += "距離 \(record.distance.walkText)・\(record.duration.walkDurationText)"
        if let steps = record.steps { s += "・\(steps.formatted())歩" }
        if !record.visitedSigns.isEmpty { s += "\nアートサイン \(record.visitedSigns.count)か所を鑑賞" }
        s += "\n\(ArtWalkEvent.officialURL.absoluteString)"
        return s
    }
}

struct StatTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// これまでの記録一覧
struct WalkHistoryView: View {
    @Environment(WalkHistoryStore.self) private var history
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Calorie.weightKey) private var weightKg: Double = Calorie.defaultWeightKg
    @State private var confirmDeleteAll = false

    var body: some View {
        Group {
            if history.records.isEmpty {
                ContentUnavailableView("まだ記録がありません",
                                       systemImage: "figure.walk",
                                       description: Text("地図の「スタート」から、歩いた道のりを記録できます。"))
            } else {
                List {
                    Section {
                        LabeledContent("合計距離", value: history.records.reduce(0) { $0 + $1.distance }.walkText)
                        LabeledContent("合計の消費カロリー（目安）",
                                       value: "\(Int(history.records.reduce(0) { $0 + $1.kcal(weightKg: weightKg) }.rounded())) kcal")
                    }
                    Section("記録") {
                        ForEach(history.records) { record in
                            NavigationLink(value: record) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.start.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    Text("\(record.distance.walkText)・\(record.duration.walkDurationText)・\(Int(record.kcal(weightKg: weightKg).rounded())) kcal")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { history.records[$0] }.forEach(history.delete)
                        }
                    }
                }
                .navigationDestination(for: WalkRecord.self) { WalkSummaryView(record: $0) }
            }
        }
        .navigationTitle("歩いた記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") { dismiss() }
            }
            if !history.records.isEmpty {
                ToolbarItem(placement: .bottomBar) {
                    Button("すべて削除", role: .destructive) { confirmDeleteAll = true }
                }
            }
        }
        .confirmationDialog("歩いた記録をすべて削除しますか？", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("すべて削除", role: .destructive) { history.deleteAll() }
        }
    }
}
