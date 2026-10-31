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
        .onAppear {
            newIDs = store.unseen
            store.markAllSeen()
        }
    }
}

/// 称号を獲得したときのお知らせ
struct AchievementToast: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            AchievementBadge(achievement: achievement, unlocked: true, size: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text("称号を獲得しました")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(achievement.title)
                    .font(.headline)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
