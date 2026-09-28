import Charts
import SwiftData
import SwiftUI

/// 削除の実績: 累計、月ごとの削減量、整理の種別の内訳、最近の削除。
struct HistoryView: View {
    @Query(sort: \DeletionRecord.date, order: .reverse) private var records: [DeletionRecord]
    @State private var months = 6
    @State private var selectedMonth: Date?

    private var summary: DeletionSummary {
        DeletionSummary.make(from: records.map(\.entry), months: months)
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "まだ削除した写真はありません",
                        systemImage: "chart.bar",
                        description: Text("削除すると、減らした容量がここに記録されます。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content(summary)
                }
            }
            .contentMargins(.top, Metrics.titleGap, for: .scrollContent)
            .background(Palette.background)
            .navigationTitle("実績")
        }
    }

    private func content(_ summary: DeletionSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("これまでに減らした容量").font(.footnote).foregroundStyle(Palette.text2)
                    Text(summary.totalBytes.formattedBytes)
                        .font(.system(size: 48, weight: .bold))
                        .monospacedDigit()
                    if let first = summary.firstDate {
                        Text("\(summary.totalCount.formatted())枚 · \(first.formatted(.dateTime.year().month()))から")
                            .font(.footnote)
                            .foregroundStyle(Palette.text2)
                            .monospacedDigit()
                    }
                }

                chartCard(summary)
                breakdownCard(summary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("最近の削除")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.text2)
                        .padding(.leading, 16)
                    VStack(spacing: 0) {
                        ForEach(Array(summary.recent.enumerated()), id: \.offset) { offset, entry in
                            HStack {
                                Text(entry.date.formatted(.dateTime.month().day()))
                                Spacer()
                                Text("\(entry.count.formatted())枚 · \(entry.bytes.formattedBytes)")
                                    .foregroundStyle(Palette.text2)
                            }
                            .monospacedDigit()
                            .frame(minHeight: 52)
                            if offset < summary.recent.count - 1 { Divider().overlay(Palette.line) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(Palette.surface, in: .rect(cornerRadius: Metrics.cardRadius))
                }
            }
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 24)
        }
    }

    // MARK: - 月ごとの削減量

    /// 最大値が 1GB 未満なら MB で表示する。
    private func unit(for summary: DeletionSummary) -> (label: String, divisor: Double) {
        (summary.monthly.map(\.bytes).max() ?? 0) >= 1_000_000_000 ? ("GB", 1e9) : ("MB", 1e6)
    }

    private func chartCard(_ summary: DeletionSummary) -> some View {
        let unit = unit(for: summary)
        let currentMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start
        let selected = selectedMonth.flatMap { date in
            summary.monthly.first { Calendar.current.isDate($0.month, equalTo: date, toGranularity: .month) }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("月ごとの削減量（\(unit.label)）").font(.subheadline.weight(.semibold))
                Spacer()
                Picker("期間", selection: $months) {
                    Text("6か月").tag(6)
                    Text("1年").tag(12)
                }
                .pickerStyle(.segmented)
                .frame(width: 124)
            }

            Chart(summary.monthly, id: \.month) { item in
                BarMark(
                    x: .value("月", item.month, unit: .month),
                    y: .value(unit.label, Double(item.bytes) / unit.divisor),
                    width: .ratio(0.6)
                )
                .foregroundStyle(Palette.chart)
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    // 当月だけ数値を直接表示（色は変えない）
                    if item.month == currentMonth, selected == nil {
                        Text((Double(item.bytes) / unit.divisor).formatted(.number.precision(.fractionLength(1))))
                            .font(.caption.bold())
                            .foregroundStyle(Palette.text)
                    }
                }

                if let selected, selected.month == item.month {
                    RuleMark(x: .value("月", selected.month, unit: .month))
                        .foregroundStyle(Palette.text2.opacity(0.4))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Text("\(selected.month.formatted(.dateTime.month())) \(selected.bytes.formattedBytes)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.text)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Palette.surface2, in: .rect(cornerRadius: 6))
                        }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(), centered: true)
                        .foregroundStyle(Palette.text2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(Palette.line)
                    AxisValueLabel().foregroundStyle(Palette.text2)
                }
            }
            .frame(height: 170)
            .accessibilityLabel("月ごとの削減量")
        }
        .card()
    }

    // MARK: - 整理の種別

    private func breakdownCard(_ summary: DeletionSummary) -> some View {
        let maxBytes = max(summary.bySource.map(\.bytes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("整理の種別").font(.subheadline.weight(.semibold))
            ForEach(summary.bySource, id: \.source) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.source.label).font(.subheadline)
                        Spacer()
                        Text(item.bytes.formattedBytes).font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.surface2)
                            Capsule().fill(Palette.chart)
                                .frame(width: proxy.size.width * CGFloat(item.bytes) / CGFloat(maxBytes))
                        }
                    }
                    .frame(height: 6)
                    .accessibilityHidden(true)
                }
            }
        }
        .card()
    }
}
