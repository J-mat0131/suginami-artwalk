import SwiftUI

/// 「すぎなみアートウォークの楽しみ方」ガイド。初回起動時に表示し、案内タブからいつでも見返せる。
struct GuideView: View {
    /// 閉じる／はじめるを押したとき
    var onFinish: () -> Void
    /// 初回表示なら最後のボタンを「はじめる」、見返しなら「閉じる」にする
    var isFirstLaunch = false

    @Environment(\.openURL) private var openURL
    @State private var page = 0

    private struct Card: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let body: String
        let tint: Color
        var link: (label: String, url: URL)? = nil
    }

    private var cards: [Card] {
        [
            Card(id: 0, icon: "paintpalette.fill",
                 title: "アートを巡って\nまち歩き",
                 body: "阿佐谷・高円寺の公園などに、女子美術大学の学生が描いたアートサインが7か所あります。一周は約5〜6km。巡る順番は自由です。",
                 tint: Theme.route),
            Card(id: 1, icon: "figure.walk",
                 title: "「スタート」で\n記録開始",
                 body: "地図の「スタート」を押して歩き出すと、歩いた道のりが地図に残ります。停止すると、距離・歩数・消費カロリーのまとめが見られます。",
                 tint: Theme.asagaya),
            Card(id: 2, icon: "camera.fill",
                 title: "「見た！」で記録、\n写真も残そう",
                 body: "アートサインの近くに来るとお知らせします。作品を見たら「見た！」をタップ。そのまま記念の写真も撮れて、あとから見返せます。7か所コンプリートを目指そう！",
                 tint: Theme.koenji),
            Card(id: 3, icon: "camera.viewfinder",
                 title: "なみすけと\n記念撮影",
                 body: "アートサインの二次元コードをスマホのカメラで読み取ると、ARでなみすけが現れ、一緒に記念撮影ができます。アプリのインストールや登録は不要です。",
                 tint: Theme.route),
            Card(id: 4, icon: "star.circle.fill",
                 title: "なみチャレで\nポイントも",
                 body: "サインの二次元コードを区の健幸アプリ「なみチャレ」で読み取ると、健康ポイントが貯まります。（このアプリの記録はポイント対象外です）",
                 tint: Theme.star,
                 link: ("なみチャレについて", ArtWalkEvent.namichareURL)),
            Card(id: 5, icon: "gift.fill",
                 title: "オリジナルグッズを\nもらおう",
                 body: "アート作品を使ったオリジナルノベルティを、阿佐谷・高円寺の商店街のお店などで配っています。どなたでも受け取れます。数に限りがあるので、配布時間・休業日を確認して立ち寄ってみてください。配布状況は変わることがあります。",
                 tint: Theme.novelty,
                 link: ("配布場所を見る（PDF）", ArtWalkEvent.noveltyPDF)),
            Card(id: 6, icon: "hand.raised.fill",
                 title: "安全に、\nまちにやさしく",
                 body: "歩きスマホはやめて、住宅街では静かに。アートサインには触れないでください。撮影のときは通行の妨げや人の写り込みに気をつけましょう。",
                 tint: Theme.accent),
        ]
    }

    private var isLast: Bool { page == cards.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("すぎなみアートウォークの楽しみ方")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if !isLast {
                    Button(isFirstLaunch ? "スキップ" : "閉じる", action: onFinish)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(height: 44)

            TabView(selection: $page) {
                ForEach(cards) { card in
                    cardView(card).tag(card.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            HStack(spacing: 8) {
                ForEach(cards) { card in
                    Capsule()
                        .fill(card.id == page ? Theme.accent : Color.secondary.opacity(0.3))
                        .frame(width: card.id == page ? 22 : 8, height: 8)
                }
            }
            .animation(.spring, value: page)
            .padding(.bottom, 20)
            .accessibilityElement()
            .accessibilityLabel("\(cards.count)ページ中\(page + 1)ページ目")

            Button {
                if isLast { onFinish() } else { page += 1 }
            } label: {
                Text(isLast ? (isFirstLaunch ? "はじめる" : "閉じる") : "次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.sky.opacity(0.5).ignoresSafeArea())
    }

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [card.tint.opacity(0.35), card.tint.opacity(0.12)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 180, height: 180)
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 124, height: 124)
                    .shadow(color: card.tint.opacity(0.25), radius: 12, y: 6)
                Image(systemName: card.icon)
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(card.tint)
            }
            .accessibilityHidden(true)

            Text(card.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.body)
                .font(.body)
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let link = card.link {
                Button {
                    openURL(link.url)
                } label: {
                    Label(link.label, systemImage: "arrow.up.right.square")
                        .font(.subheadline)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }
}
