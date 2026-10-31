import SwiftUI
import CoreLocation
import Observation

/// 称号
struct Achievement: Identifiable, Hashable {
    let id: String
    let title: String
    /// 獲得条件（ヒント）
    let condition: String
    let symbol: String
    let tint: Color
}

enum Achievements {
    static let all: [Achievement] = [
        .init(id: "first", title: "はじめの一歩", condition: "1か所目の「見た！」を記録する",
              symbol: "shoeprints.fill", tint: Theme.route),
        .init(id: "asagaya", title: "阿佐谷制覇", condition: "阿佐谷エリアの5か所をすべて巡る",
              symbol: "leaf.circle.fill", tint: Theme.asagaya),
        .init(id: "koenji", title: "高円寺制覇", condition: "高円寺エリアの2か所をすべて巡る",
              symbol: "music.note.house.fill", tint: Theme.koenji),
        .init(id: "complete", title: "アートウオーカー", condition: "7か所すべてを巡る",
              symbol: "star.circle.fill", tint: Theme.star),
        .init(id: "oneday", title: "1日で7か所", condition: "同じ日のうちに7か所すべてを巡る",
              symbol: "sun.max.circle.fill", tint: Theme.novelty),
        .init(id: "early", title: "早起きさんぽ", condition: "朝7時前に「見た！」を記録する",
              symbol: "sunrise.fill", tint: Theme.star),
        .init(id: "night", title: "夜のアート散歩", condition: "夕方6時以降に「見た！」を記録する",
              symbol: "moon.stars.fill", tint: Theme.koenji),
        .init(id: "loop", title: "一周ウオーカー", condition: "1回の記録で5km以上歩く",
              symbol: "figure.walk.circle.fill", tint: Theme.asagaya),
        .init(id: "steps10k", title: "1万歩の達人", condition: "1回の記録で1万歩以上歩く",
              symbol: "flame.circle.fill", tint: Theme.accent),
        .init(id: "total10", title: "すぎなみ10km", condition: "歩いた記録の合計が10kmを超える",
              symbol: "map.circle.fill", tint: Theme.route),
        .init(id: "photo7", title: "思い出フォトグラファー", condition: "7か所すべてで写真を残す",
              symbol: "camera.circle.fill", tint: Theme.koenji),
        .init(id: "novelty", title: "寄り道上手", condition: "記録中にノベルティ配布場所の前を通る",
              symbol: "gift.circle.fill", tint: Theme.novelty),
        .init(id: "repeat", title: "また来たよ", condition: "2日以上、歩いた記録を残す",
              symbol: "arrow.triangle.2.circlepath.circle.fill", tint: Theme.accent),
    ]

    static func find(_ id: String) -> Achievement? { all.first { $0.id == id } }

    /// 今の記録から、条件を満たしている称号を求める
    static func satisfied(progress: ProgressStore, history: WalkHistoryStore,
                          photos: PhotoStore, content: ContentStore) -> Set<String> {
        var ids = Set<String>()
        let cal = Calendar.current
        let visits = progress.visits

        if !visits.isEmpty { ids.insert("first") }
        if ArtSign.all.filter({ $0.area == .asagaya }).allSatisfy({ visits[$0.id] != nil }) { ids.insert("asagaya") }
        if ArtSign.all.filter({ $0.area == .koenji }).allSatisfy({ visits[$0.id] != nil }) { ids.insert("koenji") }
        if progress.isComplete {
            ids.insert("complete")
            let days = Set(visits.values.map { cal.startOfDay(for: $0) })
            if days.count == 1 { ids.insert("oneday") }
        }
        for date in visits.values {
            let h = cal.component(.hour, from: date)
            if (4..<7).contains(h) { ids.insert("early") }
            if h >= 18 || h < 4 { ids.insert("night") }
        }

        let records = history.records
        if records.contains(where: { $0.distance >= 5000 }) { ids.insert("loop") }
        if records.contains(where: { ($0.steps ?? 0) >= 10_000 }) { ids.insert("steps10k") }
        if records.reduce(0, { $0 + $1.distance }) >= 10_000 { ids.insert("total10") }
        if Set(records.map { cal.startOfDay(for: $0.start) }).count >= 2 { ids.insert("repeat") }

        if ArtSign.all.allSatisfy({ !photos.photos(for: $0).isEmpty }) { ids.insert("photo7") }

        // 記録した軌跡がノベルティ配布場所から40m以内を通ったか
        let spots = content.spots.compactMap { content.coordinate(for: $0) }
            .map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        if !spots.isEmpty {
            outer: for record in records {
                for p in record.points {
                    let loc = CLLocation(latitude: p.lat, longitude: p.lon)
                    if spots.contains(where: { $0.distance(from: loc) <= 40 }) {
                        ids.insert("novelty")
                        break outer
                    }
                }
            }
        }
        return ids
    }
}

/// 獲得した称号（端末内に保存）。一度獲得した称号は、記録を消しても残る。
@Observable
final class AchievementStore {
    private(set) var unlocked: [String: Date] = [:]
    /// まだ一覧で見ていない新しい称号
    private(set) var unseen: Set<String> = []
    /// 画面上部に順番に出すお知らせ
    private(set) var toastQueue: [Achievement] = []

    @ObservationIgnored private let defaults = UserDefaults.standard
    private let unlockedKey = "achievements.unlocked.v1"
    private let unseenKey = "achievements.unseen.v1"

    init() {
        if let raw = defaults.dictionary(forKey: unlockedKey) as? [String: Double] {
            unlocked = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
        unseen = Set(defaults.stringArray(forKey: unseenKey) ?? [])
    }

    var count: Int { unlocked.count }
    func isUnlocked(_ a: Achievement) -> Bool { unlocked[a.id] != nil }

    func update(with satisfied: Set<String>) {
        var changed = false
        for a in Achievements.all where satisfied.contains(a.id) && unlocked[a.id] == nil {
            unlocked[a.id] = Date()
            unseen.insert(a.id)
            toastQueue.append(a)
            changed = true
        }
        if changed { save() }
    }

    func dismissToast() {
        if !toastQueue.isEmpty { toastQueue.removeFirst() }
    }

    func markAllSeen() {
        guard !unseen.isEmpty else { return }
        unseen = []
        save()
    }

    private func save() {
        defaults.set(unlocked.mapValues { $0.timeIntervalSince1970 }, forKey: unlockedKey)
        defaults.set(Array(unseen), forKey: unseenKey)
    }
}
