import Foundation
import CoreLocation
import Observation

/// 現在地と各サインまでの距離を提供する。使用中のみの位置情報で動作。
/// ウォーキング記録中は CLBackgroundActivitySession により画面ロック中も位置を受け取る。
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    /// この距離以内なら「到着」とみなす（m）
    static let arrivalRadius: CLLocationDistance = 60

    private let manager = CLLocationManager()
    private(set) var current: CLLocation?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    /// ウォーキング記録中に、受け取った位置をすべて渡す
    @ObservationIgnored var onUpdate: ((CLLocation) -> Void)?
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?

    private var canRunInBackground: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true
    }

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

    /// ウォーキング記録用：精度を上げ、画面ロック中も記録を続ける（使用中のみの許可のまま動作）
    func beginWalkTracking() {
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        if canRunInBackground {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
            backgroundSession = CLBackgroundActivitySession()
        }
        requestAndStart()
    }

    func endWalkTracking() {
        backgroundSession?.invalidate()
        backgroundSession = nil
        if canRunInBackground {
            manager.allowsBackgroundLocationUpdates = false
        }
        manager.activityType = .other
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

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
        if let onUpdate {
            locations.forEach(onUpdate)
        }
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
