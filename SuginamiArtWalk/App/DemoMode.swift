#if DEBUG
import SwiftUI
import MapKit

/// App Store 用スクリーンショットの撮影モード（Debug ビルドのみ。App Store 版には含まれない）
/// 起動引数: -demo -demoScreen map|list|detail|summary|stamps|completion|novelty
enum DemoMode {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard isOn, let i = args.firstIndex(of: "-demoScreen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// 画面に出る日付・あいさつを固定するための日時（2026年11月8日 9:41）
    static let baseDate: Date = {
        var c = DateComponents()
        c.calendar = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")
        c.year = 2026; c.month = 11; c.day = 8; c.hour = 9; c.minute = 41
        return c.date!
    }()

    /// 起動時に一度だけ（ガイドを出さない）
    static func configureDefaults() {
        guard isOn else { return }
        UserDefaults.standard.set(true, forKey: "hasSeenGuide.v1")
    }

    @MainActor
    static func prepare(progress: ProgressStore, history: WalkHistoryStore, recorder: WalkRecorder,
                        route: RouteService, achievements: AchievementStore) async {
        let screen = screen ?? "map"
        progress.reset()
        history.deleteAll()
        achievements.demoReset()
        await route.loadIfNeeded()
        shared = route

        let t0 = baseDate.addingTimeInterval(-41 * 60) // 9:00 スタート
        func visit(_ ids: [Int]) {
            var v: [Int: Date] = [:]
            for (i, id) in ids.enumerated() { v[id] = t0.addingTimeInterval(Double(i + 1) * 17 * 60) }
            progress.demoSet(v)
        }

        switch screen {
        case "stamps":
            visit([1, 2, 3, 4, 7, 6])
            history.add(record(legs: [1, 2, 3], start: t0, visited: [1, 2, 3, 4]))
        case "completion":
            visit([1, 2, 3, 4, 5, 6, 7])
            history.add(record(legs: [1, 2, 3, 4, 5, 6, 7], start: t0, visited: [1, 2, 3, 4, 5, 6, 7]))
        case "summary", "detail", "list", "novelty":
            visit([1, 2, 3, 4])
            history.add(record(legs: [1, 2, 3], start: t0, visited: [1, 2, 3, 4]))
        default: // map：記録中の様子
            visit([1, 2, 3, 4])
            let partial = record(legs: [1, 2, 3], start: Date().addingTimeInterval(-62 * 60), visited: [])
            var pts = partial.points
            // 桃園川緑道から高円寺方面へ少し歩いたところ
            if let leg = route.legs.first(where: { $0.id == 4 }) {
                let more = coords(leg).prefix(max(1, coords(leg).count / 2))
                let last = pts.last?.t ?? Date().timeIntervalSince1970
                pts += more.enumerated().map { .init(lat: $1.latitude, lon: $1.longitude, t: last + Double($0 + 1) * 20, seg: 0) }
            }
            recorder.demoInject(start: Date().addingTimeInterval(-73 * 60 - 12), points: pts,
                                distance: partial.distance + 480, movingTime: partial.movingTime + 380,
                                steps: Int((partial.distance + 480) / 0.68))
        }

        achievements.update(with: Achievements.satisfied(
            progress: progress, history: history, photos: PhotoStore(), content: ContentStore()))
        achievements.demoClearToasts()
    }

    private static func coords(_ leg: RouteService.Leg) -> [CLLocationCoordinate2D] {
        if let line = leg.polyline {
            let p = line.points()
            return (0..<line.pointCount).map { p[$0].coordinate }
        }
        return [leg.from.coordinate, leg.to.coordinate]
    }

    /// 一周ルートの区間をつないだ、それらしい歩いた記録
    @MainActor
    private static func record(legs ids: [Int], start: Date, visited: [Int]) -> WalkRecord {
        var coordsAll: [CLLocationCoordinate2D] = []
        for id in ids {
            if let leg = shared?.legs.first(where: { $0.id == id }) { coordsAll += coords(leg) }
        }
        var dist = 0.0
        var points: [WalkRecord.Point] = []
        var t = start.timeIntervalSince1970
        var prev: CLLocation?
        for c in coordsAll {
            let loc = CLLocation(latitude: c.latitude, longitude: c.longitude)
            if let prev {
                let d = loc.distance(from: prev)
                dist += d
                t += d / 1.25
            }
            points.append(.init(lat: c.latitude, lon: c.longitude, t: t, seg: 0))
            prev = loc
        }
        let moving = dist / 1.25
        let end = start.addingTimeInterval(moving + Double(visited.count) * 4 * 60)
        return WalkRecord(id: UUID(), start: start, end: end, points: points, distance: dist,
                          movingTime: moving, steps: Int(dist / 0.68), visitedSignIDs: visited,
                          pausedTime: nil)
    }

    /// prepare 中に使うルート
    @MainActor static var shared: RouteService?
}

// MARK: - 撮影用の操作（Debug のみ）

/// 撮影モードの画面
struct DemoRoot: View {
    let screen: String
    @Environment(WalkHistoryStore.self) private var history

    var body: some View {
        switch screen {
        case "detail":
            NavigationStack { SignDetailView(sign: ArtSign.all[3]) }
        case "summary":
            NavigationStack {
                if let r = history.records.first { WalkSummaryView(record: r) }
            }
        case "stamps":
            NavigationStack { StampBookView() }
        case "completion":
            CompletionView(onClose: {})
        case "novelty":
            NavigationStack { NoveltyListView() }
        default:
            EmptyView()
        }
    }
}
#endif
