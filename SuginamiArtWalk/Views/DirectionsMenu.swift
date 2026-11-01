import SwiftUI
import MapKit
import UIKit

/// 「マップで徒歩経路を開く」：Appleマップ／Googleマップを選んで開く
struct DirectionsMenu<LabelView: View>: View {
    let name: String
    let coordinate: CLLocationCoordinate2D
    @ViewBuilder var label: () -> LabelView

    var body: some View {
        Menu {
            Button {
                Directions.openApple(name: name, coordinate: coordinate)
            } label: {
                Label("Appleマップで開く", systemImage: "map")
            }
            Button {
                Directions.openGoogle(coordinate: coordinate)
            } label: {
                Label("Googleマップで開く", systemImage: "globe")
            }
        } label: {
            label()
        }
    }
}

enum Directions {
    static func openApple(name: String, coordinate: CLLocationCoordinate2D) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    /// Googleマップのアプリがあればアプリで、なければブラウザで徒歩経路を開く（APIキー不要の公開URL）
    static func openGoogle(coordinate: CLLocationCoordinate2D) {
        let dest = "\(coordinate.latitude),\(coordinate.longitude)"
        let app = URL(string: "comgooglemaps://?daddr=\(dest)&directionsmode=walking")!
        let web = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(dest)&travelmode=walking")!
        UIApplication.shared.open(app, options: [:]) { opened in
            if !opened { UIApplication.shared.open(web) }
        }
    }
}
