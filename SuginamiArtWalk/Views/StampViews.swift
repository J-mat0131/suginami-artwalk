import SwiftUI

/// スタンプの絵柄（作品ではなく、設置場所をモチーフにしたオリジナル）
extension ArtSign {
    var stampSymbol: String {
        switch id {
        case 1: return "tram.fill"                          // 駅
        case 2: return "figure.2.and.child.holdinghands"    // 児童遊園
        case 3: return "leaf.fill"                          // 緑の公園
        case 4: return "water.waves"                        // かつての川・緑道
        case 5: return "music.note"                         // 音楽のまち高円寺
        case 6: return "tree.fill"                          // 大きな木のある公園
        default: return "building.2.fill"                   // 区民センター
        }
    }

    var stampLabel: String {
        switch id {
        case 1: return "阿佐ケ谷駅"
        case 2: return "児童遊園"
        case 3: return "にしはら公園"
        case 4: return "桃園川緑道"
        case 5: return "高円寺中央公園"
        case 6: return "馬橋公園"
        default: return "けやき公園"
        }
    }

    /// 押したスタンプらしく少し傾ける
    var stampTilt: Double { [-8, 5, -4, 7, -6, 3, -5][(id - 1) % 7] }
}

/// 押されたスタンプ
struct StampView: View {
    let sign: ArtSign
    var date: Date?
    var size: CGFloat = 120

    var body: some View {
        let color = Theme.color(for: sign.area)
        ZStack {
            Circle().stroke(color, lineWidth: size * 0.045)
            Circle()
                .inset(by: size * 0.075)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.016, dash: [size * 0.035, size * 0.022]))
            VStack(spacing: size * 0.015) {
                Image(systemName: sign.stampSymbol)
                    .font(.system(size: size * 0.3, weight: .bold))
                    .frame(height: size * 0.34)
                Text(sign.stampLabel)
                    .font(.system(size: size * 0.085, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let date {
                    Text(date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                        .font(.system(size: size * 0.07, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(size * 0.15)
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
        .rotationEffect(.degrees(sign.stampTilt))
        .opacity(0.92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sign.stampLabel)のスタンプ\(date.map { "、\($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")")
    }
}

/// まだ押していない枠
struct StampSlot: View {
    let sign: ArtSign
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            VStack(spacing: 2) {
                Image(systemName: sign.stampSymbol)
                    .font(.system(size: size * 0.22, weight: .bold))
                Text(sign.stampLabel)
                    .font(.system(size: size * 0.08, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, size * 0.12)
            }
            .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(sign.stampLabel)のスタンプ、まだ押していません")
    }
}

/// 押した瞬間の「ポン」アニメーション
struct StampPress: ViewModifier {
    let trigger: Int
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: trigger) { _, _ in
                scale = 2.0
                opacity = 0
                withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
                    scale = 1
                    opacity = 1
                }
            }
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: trigger)
    }
}

/// スタンプ帳
struct StampBookView: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(progress.visitedCount) / \(progress.total)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Text(progress.isComplete ? "スタンプがすべてそろいました！" : "「見た！」を記録するとスタンプが押されます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 22) {
                    ForEach(ArtSign.all) { sign in
                        NavigationLink(value: sign) {
                            if let date = progress.visitedDate(sign) {
                                StampView(sign: sign, date: date, size: 132)
                            } else {
                                StampSlot(sign: sign, size: 132)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(
            // 紙のような淡い背景
            LinearGradient(colors: [Color(light: 0xFBF8F1, dark: 0x1E2526), Color(light: 0xF2F7F4, dark: 0x172022)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle("スタンプ帳")
        .navigationBarTitleDisplayMode(.inline)
    }
}
