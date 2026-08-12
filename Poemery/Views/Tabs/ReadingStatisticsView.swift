import SwiftUI

struct ReadingStatisticsView: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore

    @Environment(\.chineseScriptPreference) private var script

    private var statistics: ReadingStatistics {
        session.statistics
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryCard
                weeklyCard
                recentLogCard
            }
            .screenContentPadding()
            .padding(.bottom, 52)
        }
        .navigationTitle(script.converted("阅读统计"))
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: script.converted("概览"), showsChevron: false)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                SummaryTile(
                    symbol: "clock.fill",
                    title: script.converted("累计阅读时长"),
                    value: durationText(statistics.totalDuration)
                )
                SummaryTile(
                    symbol: "sun.max.fill",
                    title: script.converted("今日阅读"),
                    value: durationText(statistics.todayDuration)
                )
                SummaryTile(
                    symbol: "flame.fill",
                    title: script.converted("连续阅读"),
                    value: script.converted("\(statistics.currentStreakDays) 天")
                )
                SummaryTile(
                    symbol: "calendar",
                    title: script.converted("阅读天数"),
                    value: script.converted("\(statistics.activeDays) 天")
                )
            }
        }
    }

    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: script.converted("最近 7 天"), showsChevron: false)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(statistics.last7Days) { day in
                        VStack(spacing: 6) {
                            Text(shortDurationText(day.duration))
                                .font(.caption2)
                                .foregroundStyle(PoemeryTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(barColor(for: day))
                                .frame(height: barHeight(for: day))

                            Text(weekdayLabel(for: day.date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PoemeryTheme.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .frame(height: 118, alignment: .bottom)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupedListBackground()
        }
    }

    private var recentLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: script.converted("最近阅读记录"), showsChevron: false)

            if statistics.recentEntries.isEmpty {
                Text(script.converted("还没有阅读记录。打开任意作品阅读后，这里会统计你的阅读时长。"))
                    .font(.subheadline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .groupedListBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(statistics.recentEntries.enumerated()), id: \.element.id) { index, entry in
                        recentRow(entry)

                        if index != statistics.recentEntries.indices.last {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .groupedListBackground()
            }
        }
    }

    private func recentRow(_ entry: ReadingLogEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 24, height: 22, alignment: .center)
                .baselineOffset(-1)

            VStack(alignment: .leading, spacing: 2) {
                Text(library.poem(id: entry.poemID)?.title ?? script.converted("作品"))
                    .font(.body)
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)

                Text(script.converted(logDateText(entry.startedAt)))
                    .font(.caption)
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Text(durationText(entry.duration))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func barHeight(for day: ReadingDayStat) -> CGFloat {
        let maxDuration = max(statistics.last7Days.map(\.duration).max() ?? 0, 1)
        let ratio = day.duration / maxDuration
        return max(6, min(64, 64 * ratio))
    }

    private func barColor(for day: ReadingDayStat) -> Color {
        day.duration > 0 ? PoemeryTheme.accent : PoemeryTheme.surface
    }

    private func weekdayLabel(for date: Date) -> String {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = Calendar.current.component(.weekday, from: date) - 1
        return symbols[weekday]
    }

    private func logDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 HH:mm"
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
        }
        return formatter.string(from: date)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return script.converted("\(hours) 小时 \(minutes) 分")
        }
        if minutes > 0 {
            return script.converted("\(minutes) 分钟")
        }
        return script.converted("\(Int(duration)) 秒")
    }

    private func shortDurationText(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return script.converted("\(Int(duration)) 秒")
        }
        let minutes = Int(duration) / 60
        return script.converted("\(minutes) 分")
    }
}

private struct SummaryTile: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 22, height: 22)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption)
                .foregroundStyle(PoemeryTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .groupedListBackground()
    }
}
