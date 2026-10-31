import SwiftUI
import CoreLocation

// MARK: - 歩数・距離・カロリーの楽しい換算

/// まとめ画面に出す「ちょっと換算」
struct FunFactsView: View {
    let distance: Double
    let kcal: Double
    let steps: Int?

    /// JR中央線 阿佐ケ谷〜高円寺の駅間（営業キロ 約1.2km）
    static let stationGap = 1200.0
    /// おにぎり1個のカロリーの目安
    static let riceBallKcal = 170.0

    private var facts: [(icon: String, text: String)] {
        var list: [(String, String)] = []
        if distance >= 50 {
            let roundTrips = distance / (Self.stationGap * 2)
            if roundTrips >= 1 {
                list.append(("tram.fill", "阿佐ケ谷駅〜高円寺駅を約\(Self.fmt(roundTrips))往復した距離です"))
            } else {
                let pct = Int((distance / Self.stationGap * 100).rounded())
                list.append(("tram.fill", pct >= 100
                             ? "阿佐ケ谷駅〜高円寺駅のひと駅分を歩きました"
                             : "阿佐ケ谷駅〜高円寺駅のひと駅分の約\(pct)%を歩きました"))
            }
        }
        if kcal >= 10 {
            let balls = kcal / Self.riceBallKcal
            list.append(("fork.knife", balls >= 1
                         ? "おにぎり約\(Self.fmt(balls))個分のカロリーを使いました"
                         : "おにぎり約\(Int((balls * 100).rounded()))%分のカロリーを使いました"))
        }
        if let steps, steps > 0 {
            list.append(("figure.walk", steps >= 10_000
                         ? "1万歩達成！ よく歩きました"
                         : "1万歩まで、あと\((10_000 - steps).formatted())歩です"))
        }
        return list
    }

    var body: some View {
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("ちょっと換算").font(.headline)
                ForEach(facts, id: \.text) { f in
                    Label(f.text, systemImage: f.icon)
                        .font(.subheadline)
                        .labelStyle(FunFactLabelStyle())
                }
                Text("※ 目安です")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.star.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    static func fmt(_ v: Double) -> String {
        v >= 10 ? "\(Int(v.rounded()))" : String(format: "%.1f", v)
    }
}

private struct FunFactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            configuration.icon
                .foregroundStyle(Theme.novelty)
                .frame(width: 22)
            configuration.title
        }
    }
}

// MARK: - ホット＆コールド

/// 次のアートサインへの近さ
enum Warmth: Int, Comparable {
    case far = 0, cool, warm, hot

    init(distance: CLLocationDistance) {
        switch distance {
        case ..<150: self = .hot
        case ..<400: self = .warm
        case ..<1000: self = .cool
        default: self = .far
        }
    }

    static func < (l: Warmth, r: Warmth) -> Bool { l.rawValue < r.rawValue }

    var text: String {
        switch self {
        case .far: return "まだ遠いよ"
        case .cool: return "少しずつ近づいてる"
        case .warm: return "近づいてきた！"
        case .hot: return "もうすぐ！"
        }
    }

    var symbol: String {
        switch self {
        case .far: return "snowflake"
        case .cool: return "thermometer.low"
        case .warm: return "thermometer.medium"
        case .hot: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .far: return Color(light: 0x4F8FD6, dark: 0x8DB8EC)
        case .cool: return Theme.route
        case .warm: return Theme.novelty
        case .hot: return Color(light: 0xE0603A, dark: 0xF08A63)
        }
    }
}

/// 地図の下に出す「次のアートサイン」の温度表示
struct WarmthBanner: View {
    let sign: ArtSign
    let distance: CLLocationDistance
    var onTap: () -> Void

    var body: some View {
        let warmth = Warmth(distance: distance)
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: warmth.symbol)
                    .font(.title3)
                    .foregroundStyle(warmth.color)
                    .frame(width: 28)
                    .symbolEffect(.pulse, isActive: warmth == .hot)
                VStack(alignment: .leading, spacing: 3) {
                    Text(warmth.text)
                        .font(.subheadline.bold())
                        .foregroundStyle(warmth.color)
                    Text("\(sign.id). \(sign.shortPlace)・\(distance.walkText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                // 4段階の温度メーター
                HStack(spacing: 3) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i <= warmth.rawValue ? warmth.color : Color.secondary.opacity(0.2))
                            .frame(width: 6, height: CGFloat(10 + i * 5))
                    }
                }
                .frame(height: 26, alignment: .bottom)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut, value: warmth)
        // 近づいたときだけ振動で知らせる
        .sensoryFeedback(trigger: warmth) { old, new in
            new > old ? .impact(weight: .medium) : nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("次のアートサイン、\(sign.shortPlace)まで\(distance.walkText)。\(warmth.text)")
    }
}

// MARK: - 時間帯・季節のあいさつ

enum Greeting {
    static func message(at date: Date = Date(), isComplete: Bool) -> String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let month = cal.component(.month, from: date)
        let seed = cal.ordinality(of: .day, in: .year, for: date) ?? 0

        // 開催期間に関するもの
        if date > ArtWalkEvent.end {
            return "アートウオークは終了しました。ご参加ありがとうございました"
        }
        if date < ArtWalkEvent.start {
            return "アートウオークは10月1日から始まります"
        }
        let daysLeft = cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                          to: cal.startOfDay(for: ArtWalkEvent.end)).day ?? 99
        if daysLeft <= 14 {
            return daysLeft == 0 ? "今日が最終日です。最後まで楽しんで！" : "開催終了まであと\(daysLeft)日です"
        }

        var options: [String]
        switch hour {
        case 4..<10:
            options = ["おはようございます。朝のまち歩きは気持ちいいですね",
                       "朝の公園で、アートをひとりじめ"]
        case 10..<16:
            options = ["のんびり、アートを巡りましょう",
                       "おなかが空いたら、商店街でひと休みも"]
        case 16..<18:
            options = ["夕方の光で見るアートも素敵です",
                       "日が暮れる前に、もう1か所いかがですか"]
        case 18..<22:
            options = ["夜は足元に気をつけて、明るい道を歩きましょう",
                       "今日もおつかれさまでした"]
        default:
            options = ["夜遅くのお散歩は気をつけて。続きはまた明日"]
        }
        switch month {
        case 10, 11: options.append("木々が色づく季節。公園の景色も楽しんで")
        case 12, 1, 2: options.append("寒い日は温かくしてお出かけを")
        case 3: options.append("春の気配。アートウオークもいよいよ終盤です")
        default: break
        }
        if isComplete { options.append("7か所コンプリート、おめでとうございます！") }
        return options[(seed + hour) % options.count]
    }
}
