import Foundation
import CoreLocation
import Observation

// MARK: - データ形式（docs/data/v1/content.json と対応）

struct RemoteContent: Codable {
    var schemaVersion: Int
    /// 区の公式情報と照らし合わせた最終確認日（yyyy-MM-dd）
    var checkedAt: String
    var novelty: Novelty
    var notices: [Notice]

    struct Novelty: Codable {
        var description: String
        var sourceURL: URL
        var spots: [NoveltySpot]
    }
}

struct NoveltySpot: Codable, Identifiable, Hashable {
    enum Status: String, Codable {
        case active, ended, upcoming
    }

    let id: String
    var area: String          // "asagaya" | "koenji"
    var street: String        // 商店街名
    var name: String
    var address: String
    var hours: String
    var closed: String
    var status: Status
    var startDate: String?    // yyyy-MM-dd（この日から配布）
    var note: String?
    var lat: Double?
    var lon: Double?

    var areaName: String { area == "koenji" ? "高円寺" : "阿佐谷" }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return .init(latitude: lat, longitude: lon)
    }

    /// 今日の時点での状態（開始日前なら upcoming 扱い）
    func currentStatus(on date: Date = Date()) -> Status {
        if status == .ended { return .ended }
        if let start = startDate.flatMap(ContentStore.day), date < start { return .upcoming }
        return .active
    }

    var statusText: String? {
        switch currentStatus() {
        case .ended: return "配布終了"
        case .upcoming:
            if let d = startDate.flatMap(ContentStore.day) {
                return "\(d.formatted(.dateTime.month().day()))から配布"
            }
            return "配布開始前"
        case .active: return nil
        }
    }
}

struct Notice: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var body: String
    /// この日まで表示（yyyy-MM-dd、省略時はずっと）
    var until: String?
    var url: URL?

    var isActive: Bool {
        guard let until, let d = ContentStore.day(until) else { return true }
        return Date() < d.addingTimeInterval(24 * 3600)
    }
}

// MARK: - 読み込み

/// 変わりやすい情報（ノベルティ配布場所・お知らせ）を GitHub Pages から読み込む。
/// 取得できないときは前回の保存分、それもなければアプリ同梱のデータを使う。
@Observable
final class ContentStore {
    static let remoteURL = URL(string: "https://j-mat0131.github.io/suginami-artwalk/data/v1/content.json")!

    private(set) var content: RemoteContent?
    /// 住所から求めた座標（データに座標がないとき用）
    private(set) var geocoded: [String: CLLocationCoordinate2D] = [:]

    @ObservationIgnored private let cacheURL = FileStorage.url("content-cache.json")
    @ObservationIgnored private let geoURL = FileStorage.url("novelty-geocode.json")
    @ObservationIgnored private var lastFetch: Date?
    @ObservationIgnored private var geocoding = false

    private struct GeoPoint: Codable { var lat: Double; var lon: Double; var address: String }

    init() {
        content = FileStorage.load(RemoteContent.self, from: cacheURL) ?? Self.bundled()
        if let saved = FileStorage.load([String: GeoPoint].self, from: geoURL) {
            geocoded = saved.mapValues { .init(latitude: $0.lat, longitude: $0.lon) }
        }
    }

    var spots: [NoveltySpot] { content?.novelty.spots ?? [] }
    var activeNotices: [Notice] { (content?.notices ?? []).filter(\.isActive) }

    var checkedAtText: String? {
        guard let s = content?.checkedAt, let d = Self.day(s) else { return nil }
        return d.formatted(.dateTime.year().month().day())
    }

    func coordinate(for spot: NoveltySpot) -> CLLocationCoordinate2D? {
        spot.coordinate ?? geocoded[spot.id]
    }

    /// 起動時・アプリに戻ったときに呼ぶ（6時間以内に取得済みなら何もしない）
    @MainActor
    func refresh(force: Bool = false) async {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < 6 * 3600 { return }
        lastFetch = Date()
        var request = URLRequest(url: Self.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let result = try? await URLSession.shared.data(for: request),
           (result.1 as? HTTPURLResponse)?.statusCode == 200,
           case let data = result.0,
           let decoded = try? JSONDecoder().decode(RemoteContent.self, from: data),
           decoded.schemaVersion == 1 {
            content = decoded
            try? data.write(to: cacheURL, options: .atomic)
        }
        await geocodeMissing()
    }

    /// 座標のない配布場所を住所から求めて保存する（Apple の住所検索を使用）
    @MainActor
    private func geocodeMissing() async {
        guard !geocoding else { return }
        geocoding = true
        defer { geocoding = false }
        let targets = spots.filter { $0.coordinate == nil && geocoded[$0.id] == nil }
        guard !targets.isEmpty else { return }
        let geocoder = CLGeocoder()
        var saved = FileStorage.load([String: GeoPoint].self, from: geoURL) ?? [:]
        for spot in targets {
            // 住所が変わったときは求め直す
            if let p = saved[spot.id], p.address == spot.address {
                geocoded[spot.id] = .init(latitude: p.lat, longitude: p.lon)
                continue
            }
            if let place = try? await geocoder.geocodeAddressString(spot.address).first,
               let c = place.location?.coordinate {
                geocoded[spot.id] = c
                saved[spot.id] = GeoPoint(lat: c.latitude, lon: c.longitude, address: spot.address)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        FileStorage.save(saved, to: geoURL)
    }

    private static func bundled() -> RemoteContent? {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RemoteContent.self, from: data)
    }

    static func day(_ s: String) -> Date? {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }
}
