import Foundation
import Observation

/// 「見た」記録をUserDefaultsに保存する。サーバー送信はしない。
@Observable
final class ProgressStore {
    private let key = "visitedSigns.v1"
    private let defaults: UserDefaults

    /// id → 記録日時
    private(set) var visits: [Int: Date] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var visitedCount: Int { visits.count }
    var total: Int { ArtSign.all.count }
    var isComplete: Bool { visitedCount == total }
    var fraction: Double { Double(visitedCount) / Double(total) }

    func isVisited(_ sign: ArtSign) -> Bool { visits[sign.id] != nil }
    func visitedDate(_ sign: ArtSign) -> Date? { visits[sign.id] }

    func markVisited(_ sign: ArtSign) {
        guard visits[sign.id] == nil else { return }
        visits[sign.id] = Date()
        save()
    }

    func unmark(_ sign: ArtSign) {
        visits[sign.id] = nil
        save()
    }

    func reset() {
        visits = [:]
        save()
    }

    /// 最初に「見た！」を記録した日時
    var firstVisitDate: Date? { visits.values.min() }
    /// 7か所そろった日時（未達成なら nil）
    var completedDate: Date? { isComplete ? visits.values.max() : nil }

    /// 未訪問のサイン（データの並び順で最初のもの）
    var nextSign: ArtSign? {
        ArtSign.all.first { visits[$0.id] == nil }
    }

    private func load() {
        guard let raw = defaults.dictionary(forKey: key) as? [String: Double] else { return }
        visits = Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
            Int(k).map { ($0, Date(timeIntervalSince1970: v)) }
        })
    }

    private func save() {
        let raw = Dictionary(uniqueKeysWithValues: visits.map { (String($0.key), $0.value.timeIntervalSince1970) })
        defaults.set(raw, forKey: key)
    }

    #if DEBUG
    /// 撮影モード用：鑑賞記録を日時つきでまとめて設定する
    func demoSet(_ v: [Int: Date]) {
        visits = v
        save()
    }
    #endif
}
