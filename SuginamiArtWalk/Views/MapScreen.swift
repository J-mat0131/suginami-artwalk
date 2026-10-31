import SwiftUI
import MapKit

struct MapScreen: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(LocationService.self) private var location
    @Environment(RouteService.self) private var route
    @Environment(WalkRecorder.self) private var recorder
    @Environment(WalkHistoryStore.self) private var history
    @Environment(ContentStore.self) private var content

    @State private var camera: MapCameraPosition = .region(MapScreen.overview)
    @State private var selected: ArtSign?
    @State private var showRoute = true
    @State private var confirmStop = false
    @State private var finishedRecord: WalkRecord?
    @State private var showHistory = false
    @State private var selectedSpot: NoveltySpot?
    @AppStorage("map.showNovelty") private var showNovelty = true

    static let overview = MKCoordinateRegion(
        center: .init(latitude: 35.7048, longitude: 139.6441),
        span: .init(latitudeDelta: 0.016, longitudeDelta: 0.022)
    )

    var body: some View {
        NavigationStack {
            Map(position: $camera, selection: $selected) {
                UserAnnotation()

                if showRoute {
                    ForEach(route.legs) { leg in
                        if let line = leg.polyline {
                            MapPolyline(line)
                                .stroke(Theme.route.opacity(0.85),
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        } else {
                            MapPolyline(coordinates: [leg.from.coordinate, leg.to.coordinate])
                                .stroke(Theme.route.opacity(0.6),
                                        style: StrokeStyle(lineWidth: 3, dash: [6, 6]))
                        }
                    }
                }

                if recorder.isRecording {
                    ForEach(Array(recorder.segments.enumerated()), id: \.offset) { _, segment in
                        if segment.count >= 2 {
                            MapPolyline(coordinates: segment)
                                .stroke(Theme.track,
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                if recorder.isRecording, let first = recorder.coordinates.first {
                    Annotation("スタート", coordinate: first, anchor: .center) {
                        Circle().fill(Theme.track).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }

                if showNovelty {
                    ForEach(content.spots.filter { $0.currentStatus() != .ended }) { spot in
                        if let c = content.coordinate(for: spot) {
                            Annotation(spot.name, coordinate: c, anchor: .center) {
                                Button { selectedSpot = spot } label: { NoveltyPin(spot: spot) }
                                    .buttonStyle(.plain)
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                }

                ForEach(ArtSign.all) { sign in
                    Annotation(sign.shortPlace, coordinate: sign.coordinate, anchor: .bottom) {
                        SignPin(sign: sign, visited: progress.isVisited(sign))
                    }
                    .tag(sign)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 8) {
                    header
                    ForEach(content.activeNotices) { notice in
                        NoticeBanner(notice: notice).padding(.horizontal, 12)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    nearbyBanner
                    walkControl
                }
                .padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedSpot) { spot in
                NavigationStack { NoveltySpotView(spot: spot) }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selected) { sign in
                NavigationStack { SignDetailView(sign: sign) }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .task { await route.loadIfNeeded() }
            .confirmationDialog("記録を終了しますか？", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("終了してまとめを見る") { finishWalk() }
                Button("記録を破棄", role: .destructive) { recorder.discard(location: location) }
                Button("記録を続ける", role: .cancel) {}
            }
            .sheet(item: $finishedRecord) { record in
                NavigationStack { WalkSummaryView(record: record, showsCloseButton: true) }
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { WalkHistoryView() }
        }
    }

    private func finishWalk() {
        guard let record = recorder.stop(location: location, progress: progress) else { return }
        // ほとんど動いていない記録は保存しない
        if record.distance >= 20 || record.duration >= 60 {
            history.add(record)
        }
        finishedRecord = record
    }

    @ViewBuilder
    private var walkControl: some View {
        if recorder.isRecording {
            VStack(alignment: .leading, spacing: 8) {
                if recorder.isPaused {
                    Label("一時停止中", systemImage: "pause.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.koenji)
                }
                HStack(spacing: 12) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 14) {
                            stat(recorder.elapsed(at: context.date).clockText, "時間")
                            stat(recorder.distance.walkText, "距離")
                            stat(recorder.steps.map { "\($0)" } ?? "—", "歩数")
                        }
                    }
                    .opacity(recorder.isPaused ? 0.5 : 1)
                    Spacer(minLength: 0)
                    if recorder.isPaused {
                        Button {
                            recorder.resume(location: location)
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.headline)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("記録を再開")
                    } else {
                        Button {
                            recorder.pause(location: location)
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.headline)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("一時停止")
                    }
                    Button {
                        confirmStop = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.headline)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel("記録を停止")
                }
            }
            .sensoryFeedback(.impact, trigger: recorder.isPaused)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 12)
        } else {
            Button {
                recorder.start(location: location)
            } label: {
                Label("スタート", systemImage: "figure.walk")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 12)
            .accessibilityHint("歩いた道のりの記録を始めます")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ProgressRing(fraction: progress.fraction, lineWidth: 5)
                .frame(width: 40, height: 40)
                .overlay(Text("\(progress.visitedCount)").font(.headline.monospacedDigit()))
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.isComplete ? "7か所コンプリート！" : "\(progress.visitedCount) / \(progress.total) か所")
                    .font(.headline)
                Group {
                    if route.totalDistance > 0 {
                        Text("一周 \(route.totalDistance.walkText)・\(route.totalDistance.walkMinutesText)")
                    } else {
                        Text(ArtWalkEvent.courseText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                TimelineView(.everyMinute) { context in
                    Text(Greeting.message(at: context.date, isComplete: progress.isComplete))
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityLabel("歩いた記録")
            Menu {
                Toggle(isOn: $showRoute.animation()) {
                    Label("おすすめルート", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                }
                Toggle(isOn: $showNovelty.animation()) {
                    Label("ノベルティ配布場所", systemImage: "gift")
                }
            } label: {
                Image(systemName: "square.3.layers.3d")
            }
            .accessibilityLabel("地図に表示するもの")
            Button {
                withAnimation { camera = .region(Self.overview) }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityLabel("全体を表示")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
    }

    /// いちばん近い未訪問のアートサイン（ホット＆コールドの目標）
    private var nearestUnvisited: (sign: ArtSign, distance: CLLocationDistance)? {
        ArtSign.all
            .filter { !progress.isVisited($0) }
            .compactMap { s in location.distance(to: s).map { (sign: s, distance: $0) } }
            .min { $0.distance < $1.distance }
    }

    @ViewBuilder
    private var nearbyBanner: some View {
        if let sign = location.nearbySign, !progress.isVisited(sign) {
            Button { selected = sign } label: {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(Theme.star)
                    VStack(alignment: .leading) {
                        Text("近くにアートサインがあります").font(.caption).foregroundStyle(.secondary)
                        Text(sign.title).font(.headline)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let target = nearestUnvisited {
            WarmthBanner(sign: target.sign, distance: target.distance) { selected = target.sign }
                .padding(.horizontal, 12)
        }
    }
}

struct SignPin: View {
    let sign: ArtSign
    let visited: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(visited ? Theme.accent : Color(.systemBackground))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Theme.color(for: sign.area), lineWidth: 3))
                .shadow(radius: 2, y: 1)
            if visited {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            } else {
                Text("\(sign.id)").font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.color(for: sign.area))
            }
        }
        .accessibilityLabel("\(sign.id)番 \(sign.place) \(visited ? "鑑賞済み" : "")")
    }
}

struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring, value: fraction)
        }
    }
}
