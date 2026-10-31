import Foundation
import CoreLocation
import CoreMotion
import Observation

/// 保存済みのウォーキング記録（Application Support/walks.json）
@Observable
final class WalkHistoryStore {
    private(set) var records: [WalkRecord] = []

    @ObservationIgnored private let url = FileStorage.url("walks.json")

    init() {
        records = FileStorage.load([WalkRecord].self, from: url) ?? []
    }

    func add(_ record: WalkRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(_ record: WalkRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func deleteAll() {
        records = []
        save()
    }

    private func save() { FileStorage.save(records, to: url) }
}

/// スタート〜停止までの軌跡・距離・歩数を記録する。
/// 記録中のデータはこまめにファイルへ書き出し、アプリが終了しても次回起動時に再開できる。
@Observable
final class WalkRecorder {
    private(set) var isRecording = false
    private(set) var startDate: Date?
    private(set) var points: [WalkRecord.Point] = []
    private(set) var distance: Double = 0
    private(set) var movingTime: TimeInterval = 0
    private(set) var steps: Int?

    @ObservationIgnored private var lastLocation: CLLocation?
    @ObservationIgnored private var rejectedInARow = 0
    @ObservationIgnored private var unsaved = 0
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let draftURL = FileStorage.url("walk-in-progress.json")

    private struct Draft: Codable {
        var start: Date
        var points: [WalkRecord.Point]
        var distance: Double
        var movingTime: TimeInterval
    }

    var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    // MARK: 操作

    func start(location: LocationService) {
        guard !isRecording else { return }
        startDate = Date()
        points = []
        distance = 0
        movingTime = 0
        steps = nil
        lastLocation = nil
        rejectedInARow = 0
        isRecording = true
        attach(location)
        saveDraft()
    }

    /// 前回アプリが終了したときに記録中だった場合は再開する（12時間以内のみ）
    func resumeIfNeeded(location: LocationService) {
        guard !isRecording, let draft = FileStorage.load(Draft.self, from: draftURL) else { return }
        guard Date().timeIntervalSince(draft.start) < 12 * 3600 else {
            FileStorage.remove(draftURL)
            return
        }
        startDate = draft.start
        points = draft.points
        distance = draft.distance
        movingTime = draft.movingTime
        if let p = draft.points.last {
            lastLocation = CLLocation(
                coordinate: .init(latitude: p.lat, longitude: p.lon),
                altitude: 0, horizontalAccuracy: 10, verticalAccuracy: -1,
                timestamp: Date(timeIntervalSince1970: p.t))
        }
        isRecording = true
        attach(location)
    }

    /// 記録を終了してまとめを返す。progress は、この間に「見た！」したサインを集計するのに使う。
    func stop(location: LocationService, progress: ProgressStore) -> WalkRecord? {
        guard isRecording, let start = startDate else { return nil }
        let end = Date()
        detach(location)
        let visited = ArtSign.all
            .filter { sign in
                guard let d = progress.visitedDate(sign) else { return false }
                return d >= start && d <= end
            }
            .map(\.id)
        let record = WalkRecord(
            id: UUID(), start: start, end: end, points: points,
            distance: distance, movingTime: movingTime, steps: steps,
            visitedSignIDs: visited)
        reset()
        return record
    }

    func discard(location: LocationService) {
        guard isRecording else { return }
        detach(location)
        reset()
    }

    // MARK: 内部処理

    private func attach(_ location: LocationService) {
        location.onUpdate = { [weak self] loc in self?.add(loc) }
        location.beginWalkTracking()
        if let start = startDate, CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: start) { [weak self] data, _ in
                guard let n = data?.numberOfSteps.intValue else { return }
                DispatchQueue.main.async { self?.steps = n }
            }
        }
    }

    private func detach(_ location: LocationService) {
        location.onUpdate = nil
        location.endWalkTracking()
        pedometer.stopUpdates()
    }

    private func reset() {
        isRecording = false
        startDate = nil
        points = []
        distance = 0
        movingTime = 0
        steps = nil
        lastLocation = nil
        FileStorage.remove(draftURL)
    }

    private func add(_ loc: CLLocation) {
        guard isRecording,
              loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 30 else { return }
        if let start = startDate, loc.timestamp < start { return }

        if let last = lastLocation {
            let d = loc.distance(from: last)
            let dt = loc.timestamp.timeIntervalSince(last.timestamp)
            guard dt > 0 else { return }
            // 立ち止まっているときのGPSの揺れは無視
            if d < max(5, loc.horizontalAccuracy * 0.5) { return }
            // 徒歩ではありえない飛び（時速25km超）は無視。続く場合は電車などで移動したとみなし、距離に足さず続きから記録
            if d / dt > 7 {
                rejectedInARow += 1
                guard rejectedInARow >= 3 else { return }
                rejectedInARow = 0
                lastLocation = loc
                append(loc)
                return
            }
            rejectedInARow = 0
            distance += d
            if d / dt >= 0.4, dt < 120 { movingTime += dt }
        }
        lastLocation = loc
        append(loc)
    }

    private func append(_ loc: CLLocation) {
        points.append(.init(lat: loc.coordinate.latitude,
                            lon: loc.coordinate.longitude,
                            t: loc.timestamp.timeIntervalSince1970))
        unsaved += 1
        if unsaved >= 10 { saveDraft() }
    }

    private func saveDraft() {
        guard let start = startDate else { return }
        unsaved = 0
        FileStorage.save(Draft(start: start, points: points, distance: distance, movingTime: movingTime), to: draftURL)
    }
}

/// Application Support 内のJSONファイル読み書き
enum FileStorage {
    static func url(_ name: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
