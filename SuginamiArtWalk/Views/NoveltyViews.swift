import SwiftUI
import MapKit

/// 地図上のノベルティ配布場所ピン
struct NoveltyPin: View {
    let spot: NoveltySpot

    var body: some View {
        let upcoming = spot.currentStatus() == .upcoming
        Image(systemName: "gift.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 21, height: 21)
            .background(Circle().fill(upcoming ? Color.gray : Theme.novelty))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 1.5, y: 1)
            .accessibilityLabel("ノベルティ配布場所 \(spot.name)\(spot.statusText.map { "、\($0)" } ?? "")")
    }
}

/// 情報の注意書き（全文）
struct NoveltyDisclaimer: View {
    @Environment(ContentStore.self) private var content
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("情報についてのご注意", systemImage: "exclamationmark.circle")
                .font(.subheadline.bold())
            Text("ノベルティの情報は、杉並区公式サイトの配布場所一覧をもとに本アプリが独自にまとめたものです。最新の状況と異なる場合があります。お出かけ前に、公式の一覧（PDF）や各店舗の営業状況をご確認ください。")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let checked = content.checkedAtText {
                    Text("最終確認日：\(checked)")
                        .font(.caption.bold())
                }
                Spacer()
                if let url = content.content?.novelty.sourceURL {
                    Button("公式の一覧（PDF）") { openURL(url) }
                        .font(.caption.bold())
                }
            }
        }
        .padding(14)
        .background(Theme.star.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 配布場所一覧
struct NoveltyListView: View {
    @Environment(ContentStore.self) private var content
    @State private var selected: NoveltySpot?

    private func spots(_ area: String) -> [NoveltySpot] {
        content.spots
            .filter { $0.area == area }
            .sorted { rank($0) < rank($1) }
    }

    private func rank(_ s: NoveltySpot) -> Int {
        switch s.currentStatus() { case .active: 0; case .upcoming: 1; case .ended: 2 }
    }

    var body: some View {
        List {
            Section {
                if let d = content.content?.novelty.description {
                    Text(d).font(.subheadline)
                }
                NoveltyDisclaimer()
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
            ForEach(["asagaya", "koenji"], id: \.self) { area in
                let list = spots(area)
                if !list.isEmpty {
                    Section(area == "koenji" ? "高円寺エリア" : "阿佐谷エリア") {
                        ForEach(list) { spot in
                            Button { selected = spot } label: { NoveltyRow(spot: spot) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("ノベルティ配布場所")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await content.refresh(force: true) }
        .sheet(item: $selected) { spot in
            NavigationStack { NoveltySpotView(spot: spot) }
                .presentationDetents([.medium, .large])
        }
    }
}

private struct NoveltyRow: View {
    let spot: NoveltySpot

    var body: some View {
        let ended = spot.currentStatus() == .ended
        HStack(alignment: .top, spacing: 12) {
            NoveltyPin(spot: spot)
                .opacity(ended ? 0.35 : 1)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(spot.name).font(.headline)
                    if let status = spot.statusText {
                        Text(status)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((ended ? Color.gray : Theme.novelty).opacity(0.2), in: Capsule())
                    }
                }
                Text(spot.street).font(.caption).foregroundStyle(.secondary)
                Text("\(spot.hours)・休み：\(spot.closed)").font(.caption)
            }
            .opacity(ended ? 0.5 : 1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

/// 配布場所の詳細
struct NoveltySpotView: View {
    let spot: NoveltySpot
    @Environment(ContentStore.self) private var content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        NoveltyPin(spot: spot)
                        Text(spot.street).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(spot.name).font(.title2.bold())
                    if let status = spot.statusText {
                        Label(status, systemImage: spot.currentStatus() == .ended ? "xmark.circle" : "calendar")
                            .font(.subheadline.bold())
                            .foregroundStyle(spot.currentStatus() == .ended ? Color.secondary : Theme.accent)
                    }
                    if let note = spot.note, spot.statusText == nil {
                        Text(note).font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                LabeledContent("配布時間", value: spot.hours)
                LabeledContent("休み", value: spot.closed)
                LabeledContent("住所", value: spot.address.replacingOccurrences(of: "東京都", with: ""))
            }
            Section {
                if let c = content.coordinate(for: spot) {
                    DirectionsMenu(name: spot.name, coordinate: c) {
                        Label("マップで徒歩経路を開く", systemImage: "figure.walk")
                    }
                }
                if let url = content.content?.novelty.sourceURL {
                    Button { openURL(url) } label: {
                        Label("区の公式の配布場所一覧（PDF）", systemImage: "doc.text")
                    }
                }
            } footer: {
                Text("最新の配布状況は公式の一覧や店舗でご確認ください。数に限りがあり、なくなり次第終了です。\(content.checkedAtText.map { "（最終確認日：\($0)）" } ?? "")")
            }
        }
        .navigationTitle("ノベルティ配布場所")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") { dismiss() }
            }
        }
    }
}

/// 区からのお知らせなど（データファイルの notices）
struct NoticeBanner: View {
    let notice: Notice
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.title).font(.subheadline.bold())
                Text(notice.body).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = notice.url {
                    Button("詳しく見る") { openURL(url) }.font(.caption.bold())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}


// MARK: - 地図用のまとめピン

/// 近い配布場所（約90m以内）をひとまとめにしたもの
struct NoveltyGroup: Identifiable {
    let id: String
    let spots: [NoveltySpot]
    let coordinate: CLLocationCoordinate2D

    var title: String {
        spots.count == 1 ? spots[0].name : "\(spots[0].street)ほか \(spots.count)か所"
    }

    static func make(from content: ContentStore, radius: CLLocationDistance = 90) -> [NoveltyGroup] {
        let items: [(NoveltySpot, CLLocation)] = content.spots
            .filter { $0.currentStatus() != .ended }
            .compactMap { s in content.coordinate(for: s).map { (s, CLLocation(latitude: $0.latitude, longitude: $0.longitude)) } }
        var groups: [[(NoveltySpot, CLLocation)]] = []
        for item in items {
            if let i = groups.firstIndex(where: { g in g.contains { $0.1.distance(from: item.1) <= radius } }) {
                groups[i].append(item)
            } else {
                groups.append([item])
            }
        }
        return groups.map { g in
            let lat = g.map { $0.1.coordinate.latitude }.reduce(0, +) / Double(g.count)
            let lon = g.map { $0.1.coordinate.longitude }.reduce(0, +) / Double(g.count)
            return NoveltyGroup(id: g.map { $0.0.id }.joined(separator: "+"),
                                spots: g.map(\.0),
                                coordinate: .init(latitude: lat, longitude: lon))
        }
    }
}

struct NoveltyGroupPin: View {
    let group: NoveltyGroup

    var body: some View {
        if group.spots.count == 1 {
            NoveltyPin(spot: group.spots[0])
        } else {
            NoveltyPin(spot: group.spots[0])
                .overlay(alignment: .topTrailing) {
                    Text("\(group.spots.count)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(Circle().fill(Theme.koenji))
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 7, y: -7)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("ノベルティ配布場所 \(group.spots.count)か所")
        }
    }
}

/// まとめピンをタップしたときの一覧
struct NoveltyGroupView: View {
    let group: NoveltyGroup
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(group.spots) { spot in
                    NavigationLink {
                        NoveltySpotView(spot: spot)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(spot.name).font(.headline)
                                if let status = spot.statusText {
                                    Text(status)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Theme.novelty.opacity(0.2), in: Capsule())
                                }
                            }
                            Text("\(spot.hours)・休み：\(spot.closed)").font(.caption)
                        }
                    }
                }
            } header: {
                Text(group.spots[0].street)
            } footer: {
                Text("最新の配布状況は公式の一覧や店舗でご確認ください。")
            }
        }
        .navigationTitle("ノベルティ配布場所")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる") { dismiss() }
            }
        }
    }
}
