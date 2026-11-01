import SwiftUI

/// 称号のメダル
struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked
                      ? AnyShapeStyle(LinearGradient(colors: [achievement.tint.opacity(0.25), achievement.tint.opacity(0.08)],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.secondary.opacity(0.1)))
            Circle()
                .strokeBorder(unlocked ? achievement.tint : Color.secondary.opacity(0.3), lineWidth: size * 0.05)
            Image(systemName: unlocked ? achievement.symbol : "lock.fill")
                .font(.system(size: size * (unlocked ? 0.46 : 0.32), weight: .semibold))
                .foregroundStyle(unlocked ? achievement.tint : Color.secondary.opacity(0.5))
        }
        .frame(width: size, height: size)
    }
}

/// 称号一覧
struct AchievementsView: View {
    /// お知らせから開いたときの「閉じる」
    var onClose: (() -> Void)? = nil

    @Environment(AchievementStore.self) private var store
    @State private var newIDs: Set<String> = []

    var body: some View {
        List {
            Section {
                HStack {
                    Text("獲得した称号")
                    Spacer()
                    Text("\(store.count) / \(Achievements.all.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
            }
            Section {
                ForEach(Achievements.all) { a in
                    let date = store.unlocked[a.id]
                    HStack(spacing: 14) {
                        AchievementBadge(achievement: a, unlocked: date != nil, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(date != nil ? a.title : "？？？")
                                    .font(.headline)
                                if newIDs.contains(a.id) {
                                    Text("NEW")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(Capsule().fill(Color.red))
                                }
                            }
                            Text(a.condition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let date {
                                Text("\(date.formatted(date: .abbreviated, time: .omitted)) 獲得")
                                    .font(.caption2)
                                    .foregroundStyle(a.tint)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .opacity(date == nil ? 0.7 : 1)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("称号")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: onClose)
                }
            }
        }
        .onAppear {
            newIDs = store.unseen
            store.markAllSeen()
        }
    }
}

/// 称号を獲得したときのお知らせ（同時に獲得したものは1つにまとめる）
struct AchievementToast: View {
    let achievements: [Achievement]

    var body: some View {
        HStack(spacing: 12) {
            if let first = achievements.first {
                AchievementBadge(achievement: first, unlocked: true, size: 44)
                    .overlay(alignment: .topTrailing) {
                        if achievements.count > 1 {
                            Text("\(achievements.count)")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Circle().fill(Color.red))
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(achievements.count > 1 ? "称号を\(achievements.count)つ獲得しました" : "称号を獲得しました")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(achievements.map(\.title).joined(separator: "・"))
                    .font(.headline)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップすると称号の一覧を開きます")
    }
}
