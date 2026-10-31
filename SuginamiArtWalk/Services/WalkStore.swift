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

/// スタート〜停止までの軌跡・距離・歩数を記録する。一時停止中は位置・時間・歩数を数えない。
/// 記録中のデータはこまめにファイルへ書き出し、アプリが終了しても次回起動時に再開できる。
@Observable
final class WalkRecorder {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var startDate: Date?
    private(set) var points: [WalkRecord.Point] = []
    private(set) var distance: Double = 0
    private(set) var movingTime: TimeInterval = 0
    /// 歩数計の値（スタートからの累計。一時停止中の分も含む）
    private(set) var rawSteps: Int?

    /// 終わった一時停止の合計時間
    private(set) var pausedTotal: TimeInterval = 0
    /// 今の一時停止が始まった時刻
    private(set) var pauseStart: Date?
    /// 一時停止中に歩いた歩数の合計（差し引く分）
    private(set) var excludedSteps = 0
    @ObservationIgnored private var stepsAtPause: Int?
    /// 軌跡の区間番号（再開するたびに増え、地図では区間ごとに線を分ける）
    @ObservationIgnored private var segment = 0

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
        var pausedTotal: TimeInterval?
        var pauseStart: Date?
        var excludedSteps: Int?
        var stepsAtPause: Int?
        var segment: Int?
    }

    /// 表示用の歩数（一時停止中の分を除く）
    var steps: Int? {
        guard let raw = rawSteps else { return nil }
        var excluded = excludedSteps
        if isPaused, let atPause = stepsAtPause { excluded += max(0, raw - atPause) }
        return max(0, raw - excluded)
    }

    /// 一時停止を除いた経過時間
    func elapsed(at now: Date = Date()) -> TimeInterval {
        guard let start = startDate else { return 0 }
        var paused = pausedTotal
        if let p = pauseStart { paused += now.timeIntervalSince(p) }
        return max(0, now.timeIntervalSince(start) - paused)
    }

    var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    /// 区間ごとの軌跡（一時停止をはさんだ前後はつながない）
    var segments: [[CLLocationCoordinate2D]] { WalkRecord.segments(of: points) }

    // MARK: 操作

    func start(location: LocationService) {
        guard !isRecording else { return }
        startDate = Date()
        points = []
        distance = 0
        movingTime = 0
        rawSteps = nil
        pausedTotal = 0
        pauseStart = nil
        excludedSteps = 0
        stepsAtPause = nil
        segment = 0
        lastLocation = nil
        rejectedInARow = 0
        isPaused = false
        isRecording = true
        attach(location)
        saveDraft()
    }

    func pause(location: LocationService) {
        guard isRecording, !isPaused else { return }
        isPaused = true
        pauseStart = Date()
        stepsAtPause = rawSteps ?? 0
        // 画面ロック中の位置取得をやめて電池を節約（記録には使わない）
        location.endWalkTracking()
        saveDraft()
    }

    func resume(location: LocationService) {
        guard isRecording, isPaused else { return }
        finishPause()
        location.beginWalkTracking()
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
        pausedTotal = draft.pausedTotal ?? 0
        pauseStart = draft.pauseStart
        excludedSteps = draft.excludedSteps ?? 0
        stepsAtPause = draft.stepsAtPause
        segment = draft.segment ?? 0
        isPaused = draft.pauseStart != nil
        if !isPaused, let p = draft.points.last {
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
        let finalSteps = steps
        if isPaused { finishPause(now: end) }
        detach(location)
        let visited = ArtSign.all
            .filter { sign in
                guard let d = progress.visitedDate(sign) else { return false }
                return d >= start && d <= end
            }
            .map(\.id)
        let record = WalkRecord(
            id: UUID(), start: start, end: end, points: points,
            distance: distance, movingTime: movingTime, steps: finalSteps,
            visitedSignIDs: visited, pausedTime: pausedTotal > 0 ? pausedTotal : nil)
        reset()
        return record
    }

    func discard(location: LocationService) {
        guard isRecording else { return }
        detach(location)
        reset()
    }

    #if DEBUG
    /// 撮影モード用：位置情報を使わずに記録中の状態を作る
    func demoInject(start: Date, points: [WalkRecord.Point], distance: Double,
                    movingTime: TimeInterval, steps: Int) {
        startDate = start
        self.points = points
        self.distance = distance
        self.movingTime = movingTime
        rawSteps = steps
        isPaused = false
        isRecording = true
    }
    #endif

    // MARK: 内部処理

    private func finishPause(now: Date = Date()) {
        if let p = pauseStart { pausedTotal += now.timeIntervalSince(p) }
        if let atPause = stepsAtPause, let raw = rawSteps { excludedSteps += max(0, raw - atPause) }
        pauseStart = nil
        stepsAtPause = nil
        isPaused = false
        segment += 1
        // 一時停止の前後は距離をつながない
        lastLocation = nil
        rejectedInARow = 0
    }

    private func attach(_ location: LocationService) {
        location.onUpdate = { [weak self] loc in self?.add(loc) }
        if !isPaused { location.beginWalkTracking() }
        if let start = startDate, CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: start) { [weak self] data, _ in
                guard let n = data?.numberOfSteps.intValue else { return }
                DispatchQueue.main.async { self?.rawSteps = n }
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
        isPaused = false
        startDate = nil
        points = []
        distance = 0
        movingTime = 0
        rawSteps = nil
        pausedTotal = 0
        pauseStart = nil
        excludedSteps = 0
        stepsAtPause = nil
        segment = 0
        lastLocation = nil
        FileStorage.remove(draftURL)
    }

    private func add(_ loc: CLLocation) {
        guard isRecording, !isPaused,
              loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 30 else { return }
        if let start = startDate, loc.timestamp < start { return }
        // 再開より前に測った位置は使わない
        if let last = points.last, loc.timestamp.timeIntervalSince1970 < last.t { return }

        if let last = lastLocation {
            let d = loc.distance(from: last)
            let dt = loc.timestamp.timeIntervalSince(last.timestamp)
            guard dt > 0 else { return }
            // 立ち止まっているときのGPSの揺れは無視
            if d < max(5, loc.horizontalAccuracy * 0.5) { return }
            // 徒歩ではありえない飛び（時速25km超）は無視。続く場合は電車などで移動したとみなし、距離に足さず新しい区間として記録
            if d / dt > 7 {
                rejectedInARow += 1
                guard rejectedInARow >= 3 else { return }
                rejectedInARow = 0
                segment += 1
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
                            t: loc.timestamp.timeIntervalSince1970,
                            seg: segment))
        unsaved += 1
        if unsaved >= 10 { saveDraft() }
    }

    private func saveDraft() {
        guard let start = startDate else { return }
        unsaved = 0
        FileStorage.save(Draft(start: start, points: points, distance: distance, movingTime: movingTime,
                               pausedTotal: pausedTotal, pauseStart: pauseStart,
                               excludedSteps: excludedSteps, stepsAtPause: stepsAtPause,
                               segment: segment),
                         to: draftURL)
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
