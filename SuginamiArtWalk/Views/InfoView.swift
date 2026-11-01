import SafariServices
import SwiftUI

struct InfoView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(ContentStore.self) private var content
    @Environment(\.openURL) private var openURL
    @State private var confirmReset = false
    @State private var showGuide = false
    @State private var webPage: WebPage?
    @AppStorage(AchievementStore.toastEnabledKey) private var achievementToast = true

    private struct WebPage: Identifiable {
        let url: URL
        var id: URL { url }
    }

    private var versionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(v)（\(b)）"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showGuide = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(
                                    LinearGradient(colors: [Theme.asagaya, Theme.route, Theme.koenji],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("すぎなみアートウォークの楽しみ方")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("巡り方・記録・写真・ノベルティを6ステップで")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }

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

                if !content.activeNotices.isEmpty {
                    Section("お知らせ") {
                        ForEach(content.activeNotices) { notice in
                            NoticeBanner(notice: notice)
                                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        }
                    }
                }

                Section {
                    NavigationLink {
                        NoveltyListView()
                    } label: {
                        Label("ノベルティ配布場所", systemImage: "gift")
                    }
                } header: {
                    Text("ノベルティ")
                } footer: {
                    Text("アート作品を使ったオリジナルノベルティを商店街のお店などで配布中（数量限定）。\(content.checkedAtText.map { "最終確認日：\($0)" } ?? "")")
                }

                Section("公式資料") {
                    link("イベント公式ページ", ArtWalkEvent.officialURL, icon: "globe")
                    link("推奨コースマップ（PDF）", ArtWalkEvent.routeMapPDF, icon: "map")
                    link("ノベルティ配布場所一覧（PDF）", ArtWalkEvent.noveltyPDF, icon: "doc.text")
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

                Section {
                    Toggle(isOn: $achievementToast) {
                        Label("称号を獲得したときのお知らせ", systemImage: "rosette")
                    }
                } header: {
                    Text("お知らせ")
                } footer: {
                    Text("オフにしても、称号はアートタブの「称号」で確認できます。")
                }

                Section {
                    Button { webPage = WebPage(url: ArtWalkEvent.supportURL) } label: {
                        Label("お問い合わせ・よくある質問", systemImage: "envelope")
                    }
                    Button { webPage = WebPage(url: ArtWalkEvent.privacyURL) } label: {
                        Label("プライバシーポリシー", systemImage: "hand.raised")
                    }
                    LabeledContent("バージョン", value: versionText)
                } header: {
                    Text("このアプリについて")
                } footer: {
                    Text("イベントそのものについてのお問い合わせ（アートサインの破損の連絡など）は、上の「イベント公式ページ」に記載の連絡先へお願いします。このアプリについてのお問い合わせは、区ではなく「お問い合わせ」からお送りください。")
                }

                Section {
                    Button("鑑賞記録をリセット", role: .destructive) { confirmReset = true }
                        .disabled(progress.visitedCount == 0)
                } footer: {
                    Text("このアプリは杉並区とは関係のない非公式アプリです。情報は2026年10月30日時点の区公式ページをもとにしています。最新情報は必ず公式ページでご確認ください。位置情報・歩いた記録・鑑賞記録・撮影した写真は端末内にのみ保存され、外部に送信されることはありません。")
                }
            }
            .navigationTitle("案内")
            .sheet(isPresented: $showGuide) {
                GuideView(onFinish: { showGuide = false })
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $webPage) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
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


/// アプリ内でWebページを開く（サポートページ・プライバシーポリシー）
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(Theme.accent)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
