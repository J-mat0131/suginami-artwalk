import SwiftUI

@main
struct SuginamiArtWalkApp: App {
    @State private var progress = ProgressStore()
    @State private var location = LocationService()
    @State private var route = RouteService()
    @State private var recorder = WalkRecorder()
    @State private var history = WalkHistoryStore()
    @State private var photos = PhotoStore()
    @State private var content = ContentStore()
    @State private var achievements = AchievementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(location)
                .environment(route)
                .environment(recorder)
                .environment(history)
                .environment(photos)
                .environment(content)
                .environment(achievements)
                .tint(Theme.accent)
        }
    }
}

/// 配色はイベントのメインビジュアル（水色の空・アクア・緑・ラベンダー・淡い黄）に合わせている。
/// 文字やボタンに使う色は白背景で読めるよう、元の色より少し濃くしている。
enum Theme {
    /// ボタンやリンクなどの基本色（アクアを濃くしたティール）
    static let accent = Color(light: 0x347F8C, dark: 0x7FCBD3)
    /// 地図上の徒歩ルート（リボンのアクア）
    static let route = Color(light: 0x5FB3C2, dark: 0x7FCBD3)
    /// 阿佐谷エリア（タイトル「阿佐谷」の緑）
    static let asagaya = Color(light: 0x4E9E75, dark: 0x6CC093)
    /// 高円寺エリア（タイトル「高円寺」のラベンダー）
    static let koenji = Color(light: 0x7E6DB4, dark: 0xA897E0)
    /// 星・太陽の淡い黄
    static let star = Color(light: 0xE8B84A, dark: 0xFBE299)
    /// ノベルティ配布場所（メインビジュアルの太陽の黄色を少し濃く）
    static let novelty = Color(light: 0xD9A23A, dark: 0xE8B84A)
    /// 自分が歩いた軌跡
    static let track = Color(light: 0x7E6DB4, dark: 0xB7A8F0)
    /// カード背景の淡い空色
    static let sky = Color(light: 0xE6F4F6, dark: 0x1F3236)

    static func color(for area: ArtSign.Area) -> Color {
        area == .koenji ? koenji : asagaya
    }
}

extension Color {
    /// ライト／ダークで切り替わる色を16進数で指定する
    init(light: UInt32, dark: UInt32) {
        func ui(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
        }
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
}

struct ContentView: View {
    @Environment(LocationService.self) private var location
    @Environment(WalkRecorder.self) private var recorder
    @Environment(ContentStore.self) private var content
    @Environment(ProgressStore.self) private var progress
    @Environment(WalkHistoryStore.self) private var history
    @Environment(PhotoStore.self) private var photos
    @Environment(AchievementStore.self) private var achievements
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasSeenGuide.v1") private var hasSeenGuide = false

    private func evaluateAchievements() {
        achievements.update(with: Achievements.satisfied(
            progress: progress, history: history, photos: photos, content: content))
    }

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("マップ", systemImage: "map") }
            SignListView()
                .tabItem { Label("アート", systemImage: "paintpalette") }
            InfoView()
                .tabItem { Label("案内", systemImage: "info.circle") }
        }
        .task {
            // 初回はガイドを読み終えてから位置情報の許可を求める
            if hasSeenGuide { location.requestAndStart() }
            recorder.resumeIfNeeded(location: location)
            evaluateAchievements()
            await content.refresh()
            evaluateAchievements()
        }
        .onChange(of: progress.visitedCount) { _, _ in evaluateAchievements() }
        .onChange(of: history.records.count) { _, _ in evaluateAchievements() }
        .onChange(of: photos.photos.count) { _, _ in evaluateAchievements() }
        .overlay(alignment: .top) {
            if let toast = achievements.toastQueue.first {
                AchievementToast(achievement: toast)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { achievements.dismissToast() } }
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 3_200_000_000)
                        withAnimation(.easeInOut) { achievements.dismissToast() }
                    }
                    .sensoryFeedback(.success, trigger: toast.id)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: achievements.toastQueue.first?.id)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await content.refresh() } }
        }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenGuide }, set: { if !$0 { hasSeenGuide = true } })) {
            GuideView(onFinish: {
                hasSeenGuide = true
                location.requestAndStart()
            }, isFirstLaunch: true)
        }
    }
}
