import SwiftUI
import UIKit

/// 称号のお知らせを、シートやカメラより手前に出すための透明なウィンドウ。
/// お知らせの部分だけタップを受け取り、ほかの場所のタップは下の画面へそのまま通す。
@MainActor
final class AchievementToastWindow {
    static let shared = AchievementToastWindow()
    private var window: PassthroughWindow?

    func install(store: AchievementStore) {
        #if DEBUG
        if DemoMode.isOn { return }   // 撮影モードでは出さない
        #endif
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ??
                UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let w = PassthroughWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        let host = UIHostingController(rootView: AchievementToastHost(window: w).environment(store))
        host.view.backgroundColor = .clear
        w.rootViewController = host
        w.isHidden = false
        window = w
    }
}

final class PassthroughWindow: UIWindow {
    /// お知らせが表示されている範囲
    var interactiveRect: CGRect = .zero
    /// 称号一覧を開いている間は、すべてのタップを受け取る
    var capturesAll = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard capturesAll || interactiveRect.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct AchievementToastHost: View {
    let window: PassthroughWindow

    @Environment(AchievementStore.self) private var store
    @AppStorage(AchievementStore.toastEnabledKey) private var enabled = true
    @State private var current: [Achievement] = []
    @State private var showList = false
    @State private var generation = 0

    var body: some View {
        VStack {
            if !current.isEmpty {
                AchievementToast(achievements: current)
                    .background(
                        GeometryReader { g in
                            Color.clear
                                .onAppear { window.interactiveRect = g.frame(in: .global) }
                                .onChange(of: g.frame(in: .global)) { _, f in window.interactiveRect = f }
                        }
                    )
                    .onTapGesture {
                        hide()
                        showList = true
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, 6)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current.map(\.id))
        .sensoryFeedback(.success, trigger: current.first?.id)
        .task { present() }
        .onChange(of: store.toastQueue.count) { _, _ in present() }
        .onChange(of: store.isSuspended) { _, _ in present() }
        .onChange(of: showList) { _, shown in window.capturesAll = shown }
        .sheet(isPresented: $showList) {
            NavigationStack {
                AchievementsView(onClose: { showList = false })
            }
            .environment(store)
        }
    }

    private func present() {
        guard current.isEmpty, !showList, !store.isSuspended, !store.toastQueue.isEmpty else { return }
        let items = store.takeAllToasts()
        guard enabled else { return }
        current = items
        generation += 1
        let mine = generation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            if generation == mine { hide() }
        }
    }

    private func hide() {
        current = []
        window.interactiveRect = .zero
        // 待っている間に増えた分があれば続けて出す
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            present()
        }
    }
}
