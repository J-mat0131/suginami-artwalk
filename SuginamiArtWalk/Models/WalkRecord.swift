import Foundation
import CoreLocation

/// 1回分のウォーキング記録。端末内にのみ保存する。
struct WalkRecord: Codable, Identifiable, Hashable {
    struct Point: Codable, Hashable {
        var lat: Double
        var lon: Double
        var t: TimeInterval
        /// 区間番号（一時停止や電車移動で分かれる。古い記録では nil）
        var seg: Int? = nil
    }

    let id: UUID
    var start: Date
    var end: Date
    var points: [Point]
    /// GPSの軌跡から求めた距離（m）
    var distance: Double
    /// 実際に歩いていた時間（立ち止まっていた時間を除く）
    var movingTime: TimeInterval
    /// iPhoneの歩数計による歩数（取得できなかった場合は nil）
    var steps: Int?
    /// この記録中に「見た！」を記録したサインのid
    var visitedSignIDs: [Int]
    /// 一時停止していた合計時間
    var pausedTime: TimeInterval? = nil

    /// 一時停止を除いた、かかった時間
    var duration: TimeInterval { max(0, end.timeIntervalSince(start) - (pausedTime ?? 0)) }

    /// 区間ごとの軌跡
    var segments: [[CLLocationCoordinate2D]] { Self.segments(of: points) }

    static func segments(of points: [Point]) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        var seg: Int? = points.first?.seg
        for p in points {
            if p.seg != seg {
                if !current.isEmpty { result.append(current) }
                current = []
                seg = p.seg
            }
            current.append(.init(latitude: p.lat, longitude: p.lon))
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    /// 歩いていた時間での平均の速さ（km/h）
    var averageSpeedKmh: Double {
        movingTime > 0 ? distance / movingTime * 3.6 : 0
    }

    var visitedSigns: [ArtSign] {
        ArtSign.all.filter { visitedSignIDs.contains($0.id) }
    }

    func kcal(weightKg: Double) -> Double {
        Calorie.kcal(weightKg: weightKg, movingTime: movingTime, distance: distance)
    }
}

/// 消費カロリーの目安。
/// kcal = METs × 体重(kg) × 時間(h) × 1.05
/// METs は国立健康・栄養研究所「改訂版 身体活動のメッツ（METs）表」の歩行の値を、歩く速さに応じて使う。
enum Calorie {
    static let defaultWeightKg: Double = 60
    static let weightKey = "bodyWeightKg"

    static func mets(speedKmh: Double) -> Double {
        switch speedKmh {
        case ..<3.2: return 2.0   // ゆっくり歩く
        case ..<4.0: return 2.8   // 3.2 km/h 程度
        case ..<4.5: return 3.0   // 4.0 km/h 程度
        case ..<5.3: return 3.5   // 4.5〜5.1 km/h（ふつうの速さ）
        case ..<6.0: return 4.3   // 5.6 km/h 程度（やや速歩）
        default:     return 5.0   // 6.4 km/h 程度（速歩）
        }
    }

    static func kcal(weightKg: Double, movingTime: TimeInterval, distance: Double) -> Double {
        guard movingTime > 0 else { return 0 }
        let speed = distance / movingTime * 3.6
        return mets(speedKmh: speed) * weightKg * (movingTime / 3600) * 1.05
    }
}

// MARK: - 表示用フォーマット

extension TimeInterval {
    /// 「1時間02分」「12分34秒」形式
    var walkDurationText: String {
        let total = Int(self.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d時間%02d分", h, m) }
        return String(format: "%d分%02d秒", m, s)
    }

    /// 記録中のタイマー用「0:12:34」形式
    var clockText: String {
        let total = max(0, Int(self))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
