import Foundation
import MapKit
import Observation

/// 7か所を一周する徒歩ルートの例をMapKitで計算する（巡る順番は自由）。
/// 取得できなかった区間は直線でつなぐ。
@Observable
final class RouteService {
    struct Leg: Identifiable {
        let id: Int            // 出発サインのid
        let from: ArtSign
        let to: ArtSign
        let polyline: MKPolyline?
        let distance: CLLocationDistance
        let expectedTime: TimeInterval
    }

    private(set) var legs: [Leg] = []
    private(set) var isLoading = false

    var totalDistance: CLLocationDistance { legs.reduce(0) { $0 + $1.distance } }
    var totalTime: TimeInterval { legs.reduce(0) { $0 + $1.expectedTime } }

    @MainActor
    func loadIfNeeded() async {
        guard legs.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let signs = ArtSign.all
        // 最後のサインから駅へ戻る区間も含めて一周
        let pairs = zip(signs, signs.dropFirst() + [signs[0]])

        var result: [Leg] = []
        for (a, b) in pairs {
            result.append(await leg(from: a, to: b))
        }
        legs = result
    }

    private func leg(from a: ArtSign, to b: ArtSign) async -> Leg {
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: a.coordinate))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: b.coordinate))
        req.transportType = .walking

        if let route = try? await MKDirections(request: req).calculate().routes.first {
            return Leg(id: a.id, from: a, to: b, polyline: route.polyline,
                       distance: route.distance, expectedTime: route.expectedTravelTime)
        }
        let straight = a.location.distance(from: b.location)
        return Leg(id: a.id, from: a, to: b, polyline: nil,
                   distance: straight * 1.3, expectedTime: straight * 1.3 / 1.33)
    }
}
