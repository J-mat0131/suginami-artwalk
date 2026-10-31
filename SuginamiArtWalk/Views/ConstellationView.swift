import SwiftUI

/// すぎなみ座：7か所の位置を星に見立て、巡った順に線でつなぐ
struct ConstellationView: View {
    /// 表示したら星を順に灯すアニメーションをする
    var animated = true
    var height: CGFloat = 260

    @Environment(ProgressStore.self) private var progress
    @State private var litCount = 0
    @State private var lineProgress: CGFloat = 0
    @State private var twinkle = false

    /// 巡った順のサイン
    private var order: [ArtSign] {
        ArtSign.all
            .compactMap { s in progress.visitedDate(s).map { (s, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let pts = Self.project(in: rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.16))
            let visitedOrder = order
            ZStack {
                LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.28),
                                        Color(red: 0.25, green: 0.22, blue: 0.48)],
                               startPoint: .top, endPoint: .bottom)
                StarField(seed: 7)
                    .opacity(twinkle ? 0.9 : 0.55)

                // 巡った順の線
                Path { path in
                    for (i, s) in visitedOrder.enumerated() {
                        guard let p = pts[s.id] else { continue }
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                }
                .trim(from: 0, to: lineProgress)
                .stroke(Color.white.opacity(0.75),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .shadow(color: Theme.star.opacity(0.6), radius: 4)

                // 星
                ForEach(ArtSign.all) { s in
                    if let p = pts[s.id] {
                        let rank = visitedOrder.firstIndex(of: s)
                        let lit = rank.map { $0 < litCount } ?? false
                        StarDot(lit: lit)
                            .position(p)
                    }
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("すぎなみ座")
                                .font(.system(.headline, design: .serif).bold())
                            Text(visitedOrder.isEmpty ? "巡った順に星がつながります" :
                                    visitedOrder.count == 7 ? "あなたが巡った順に、7つの星をつなぎました" :
                                    "\(visitedOrder.count)つの星が灯りました")
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(14)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("すぎなみ座。\(order.count)個の星が灯っています。")
        .onAppear(perform: start)
        .onChange(of: progress.visitedCount) { _, _ in start() }
    }

    private func start() {
        let n = order.count
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { twinkle = true }
        guard animated else {
            litCount = n
            lineProgress = 1
            return
        }
        litCount = 0
        lineProgress = 0
        Task { @MainActor in
            for i in 1...max(n, 1) where n > 0 {
                try? await Task.sleep(nanoseconds: 380_000_000)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { litCount = i }
            }
            withAnimation(.easeInOut(duration: 1.4)) { lineProgress = 1 }
        }
    }

    /// 緯度経度を画面の座標に変換（縦横比を保つ）
    static func project(in rect: CGRect) -> [Int: CGPoint] {
        let lats = ArtSign.all.map(\.latitude), lons = ArtSign.all.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return [:] }
        let k = cos(35.7 * .pi / 180)
        let w = (maxLon - minLon) * k, h = maxLat - minLat
        let scale = min(rect.width / w, rect.height / h)
        let ox = rect.minX + (rect.width - w * scale) / 2
        let oy = rect.minY + (rect.height - h * scale) / 2
        var out: [Int: CGPoint] = [:]
        for s in ArtSign.all {
            out[s.id] = CGPoint(x: ox + (s.longitude - minLon) * k * scale,
                                y: oy + (maxLat - s.latitude) * scale)
        }
        return out
    }
}

private struct StarDot: View {
    let lit: Bool

    var body: some View {
        ZStack {
            if lit {
                Circle()
                    .fill(Theme.star.opacity(0.35))
                    .frame(width: 30, height: 30)
                    .blur(radius: 6)
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.65))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 7, height: 7)
            }
        }
        .scaleEffect(lit ? 1 : 0.9)
    }
}

/// 背景の小さな星（毎回同じ配置）
private struct StarField: View {
    let seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: seed)
            for _ in 0..<70 {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let r = Double.random(in: 0.4...1.3, using: &rng)
                let a = Double.random(in: 0.25...0.8, using: &rng)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// すぎなみ座の画面
struct ConstellationScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ConstellationView(animated: true, height: 360)
                Text("7か所のアートサインの位置を星に見立てています。「見た！」を記録すると星が灯り、あなたが巡った順に線でつながります。7つそろうと、あなただけの「すぎなみ座」の完成です。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle("すぎなみ座")
        .navigationBarTitleDisplayMode(.inline)
    }
}
