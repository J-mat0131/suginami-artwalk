import SwiftUI

@main
struct SuginamiArtWalkApp: App {
    @State private var progress = ProgressStore()
    @State private var location = LocationService()
    @State private var route = RouteService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(location)
                .environment(route)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    /// 桃園川にちなんだ桃色
    static let accent = Color(red: 0.89, green: 0.42, blue: 0.47)
    static let leaf = Color(red: 0.30, green: 0.58, blue: 0.42)
    static let night = Color(red: 0.16, green: 0.20, blue: 0.38)

    static func color(for area: ArtSign.Area) -> Color {
        area == .koenji ? night : leaf
    }
}

struct ContentView: View {
    @Environment(LocationService.self) private var location

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("マップ", systemImage: "map") }
            SignListView()
                .tabItem { Label("アート", systemImage: "paintpalette") }
            InfoView()
                .tabItem { Label("案内", systemImage: "info.circle") }
        }
        .task { location.requestAndStart() }
    }
}
