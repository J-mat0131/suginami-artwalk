import Foundation
import CoreLocation
import Observation

/// 現在地と各サインまでの距離を提供する。使用中のみの位置情報で動作。
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    /// この距離以内なら「到着」とみなす（m）
    static let arrivalRadius: CLLocationDistance = 60

    private let manager = CLLocationManager()
    private(set) var current: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        authorization = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    func requestAndStart() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() { manager.stopUpdatingLocation() }

    func distance(to sign: ArtSign) -> CLLocationDistance? {
        current?.distance(from: sign.location)
    }

    func isNear(_ sign: ArtSign) -> Bool {
        guard let d = distance(to: sign) else { return false }
        return d <= Self.arrivalRadius
    }

    /// 近くにあるサイン（最も近いもの）
    var nearbySign: ArtSign? {
        guard current != nil else { return nil }
        return ArtSign.all
            .filter { isNear($0) }
            .min { (distance(to: $0) ?? .infinity) < (distance(to: $1) ?? .infinity) }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isAuthorized { manager.startUpdatingLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0, last.horizontalAccuracy < 100 else { return }
        current = last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 一時的な取得失敗は無視（次回更新を待つ）
    }
}

extension CLLocationDistance {
    /// 「120 m」「1.4 km」形式
    var walkText: String {
        self < 1000 ? "\(Int(self.rounded())) m" : String(format: "%.1f km", self / 1000)
    }

    /// 徒歩 80m/分 換算
    var walkMinutesText: String {
        "徒歩約\(max(1, Int((self / 80).rounded())))分"
    }
}
