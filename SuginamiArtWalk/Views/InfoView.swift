import SwiftUI

struct InfoView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.openURL) private var openURL
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("期間", value: ArtWalkEvent.periodText)
                    LabeledContent("エリア", value: "阿佐谷・高円寺")
                    LabeledContent("コース", value: ArtWalkEvent.courseText)
                    LabeledContent("対象", value: "どなたでも")
                    if !ArtWalkEvent.isOngoing {
                        Label("現在は開催期間外です", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text(ArtWalkEvent.name)
                } footer: {
                    Text("令和7年度 杉並区 区民参加型予算事業。アートは女子美術大学の学生による制作です。")
                }

                Section("公式資料") {
                    link("イベント公式ページ", ArtWalkEvent.officialURL, icon: "globe")
                    link("推奨コースマップ（PDF）", ArtWalkEvent.routeMapPDF, icon: "map")
                    link("ノベルティ配布場所（PDF）", ArtWalkEvent.noveltyPDF, icon: "gift")
                }

                Section {
                    Text("サインの二次元コードを「なみチャレ」で読み取ると健康ポイントが貯まります（参加10pt、1か所20pt、7か所達成でさらに100pt）。ARでなみすけと記念撮影もできます。")
                        .font(.subheadline)
                    link("なみチャレについて", ArtWalkEvent.namichareURL, icon: "figure.walk.circle")
                } header: {
                    Text("健康ポイント（なみチャレ）")
                } footer: {
                    Text("18歳以上の区内在住・在勤・在学の方が対象。予算上限に達した時点で付与終了。詳細は公式ページでご確認ください。")
                }

                Section("歩くときのお願い") {
                    rule("figure.walk", "交通ルールを守り、歩きスマホはやめましょう")
                    rule("house", "住宅地では静かに。道をふさがず私有地に入らない")
                    rule("hand.raised", "アートサインに触れたり動かしたりしない")
                    rule("cloud.rain", "天候・体調に合わせて無理せずに")
                    rule("camera", "撮影時は通行の妨げと写り込みに配慮")
                }

                Section("お問い合わせ（杉並区 都市整備部管理課）") {
                    Button {
                        openURL(URL(string: "tel:\(ArtWalkEvent.contactPhone.replacingOccurrences(of: "-", with: ""))")!)
                    } label: {
                        Label(ArtWalkEvent.contactPhone, systemImage: "phone")
                    }
                    link("お問い合わせフォーム", ArtWalkEvent.contactFormURL, icon: "envelope")
                    Text("サインの破損を見つけたら区へお知らせください。本アプリについての問い合わせは区へ送らないでください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("鑑賞記録をリセット", role: .destructive) { confirmReset = true }
                        .disabled(progress.visitedCount == 0)
                } footer: {
                    Text("このアプリは杉並区とは関係のない非公式アプリです。情報は2026年10月30日時点の区公式ページをもとにしています。最新情報は必ず公式ページでご確認ください。位置情報・歩いた記録・鑑賞記録は端末内にのみ保存され、外部に送信されることはありません。")
                }
            }
            .navigationTitle("案内")
            .confirmationDialog("鑑賞記録をすべて消しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("リセット", role: .destructive) { progress.reset() }
            }
        }
    }

    private func link(_ title: String, _ url: URL, icon: String) -> some View {
        Button { openURL(url) } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func rule(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.subheadline)
    }
}
