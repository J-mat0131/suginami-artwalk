import SwiftUI
import MapKit

struct MapScreen: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(LocationService.self) private var location
    @Environment(RouteService.self) private var route
    @Environment(WalkRecorder.self) private var recorder
    @Environment(WalkHistoryStore.self) private var history

    @State private var camera: MapCameraPosition = .region(MapScreen.overview)
    @State private var selected: ArtSign?
    @State private var showRoute = true
    @State private var confirmStop = false
    @State private var finishedRecord: WalkRecord?
    @State private var showHistory = false

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

                if recorder.isRecording, recorder.points.count >= 2 {
                    MapPolyline(coordinates: recorder.coordinates)
                        .stroke(Theme.track,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
                if recorder.isRecording, let first = recorder.coordinates.first {
                    Annotation("スタート", coordinate: first, anchor: .center) {
                        Circle().fill(Theme.track).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
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
            .safeAreaInset(edge: .top) { header }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    nearbyBanner
                    walkControl
                }
                .padding(.bottom, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
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
            HStack(spacing: 14) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(recorder.startDate ?? context.date)
                    HStack(spacing: 14) {
                        stat(elapsed.clockText, "時間")
                        stat(recorder.distance.walkText, "距離")
                        stat(recorder.steps.map { "\($0)" } ?? "—", "歩数")
                    }
                }
                Spacer(minLength: 0)
                Button {
                    confirmStop = true
                } label: {
                    Label("停止", systemImage: "stop.fill")
                        .font(.headline)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel("記録を停止")
            }
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
            }
            Spacer()
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .accessibilityLabel("歩いた記録")
            Button {
                withAnimation { showRoute.toggle() }
            } label: {
                Image(systemName: showRoute ? "point.topleft.down.to.point.bottomright.curvepath.fill"
                                            : "point.topleft.down.to.point.bottomright.curvepath")
            }
            .accessibilityLabel(showRoute ? "ルートを隠す" : "ルートを表示")
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
        } else if let next = progress.nextSign, let d = location.distance(to: next) {
            Button { selected = next } label: {
                HStack {
                    Text("次は")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(next.id). \(next.shortPlace)").font(.subheadline.bold())
                    Spacer()
                    Text(d.walkText).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
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
