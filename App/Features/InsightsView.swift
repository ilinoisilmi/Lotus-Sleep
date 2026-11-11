import SwiftUI
struct InsightsView:View {
    @EnvironmentObject private var store:AppStore
    var body:some View {
        let days=SleepCalendar.days(records:store.data.effectiveRecords,endingOn:store.now,count:30,preferences:store.data.preferences)
        let values=days.compactMap(\.hours)
        let wakes=days.compactMap{$0.sleep.segments.last(where:{$0.record.stage.isAsleep && $0.record.kind != .nap})?.end}
        let variation=SleepInsights.timingVariation(wakeDates:wakes,calendar:SleepCalendar.calendar(zoneID:store.data.preferences.reportingTimeZoneID))
        let tags=Set(store.data.diaries.filter{!$0.isDeleted}.flatMap{$0.current.tags}).sorted()
        LumaPage {
            SectionTitle(title:"Notice your patterns.",subtitle:"Curiosity over perfect numbers.")
            if values.isEmpty { EmptyPanel(symbol:"waveform.path",title:"Give your patterns time",text:"Your own history will appear here as you log sleep. You can explore sample history in Settings → Demo mode.") }
            else {
                Surface { Eyebrow(text:"Last 30 sleep days"); Text(Luma.duration(values.reduce(0,+)/Double(values.count)*3600)).font(.system(.largeTitle,design:.rounded,weight:.medium)); Text("Average across \(values.count) recorded days").foregroundStyle(.secondary); SleepBarChart(days:days,target:store.data.preferences.targetHours,zoneID:store.data.preferences.reportingTimeZoneID) }
                Surface { Text("Wake-time regularity").font(.headline); Text(variation.map{"About \(Int($0.rounded())) minutes of variation"} ?? "Needs at least three recorded wake times").font(.title3); Text("Circular standard deviation of main wake times in your chosen reporting timezone. Travel or a changing schedule can affect this.").font(.caption).foregroundStyle(.secondary) }
                let ratings=store.data.diaries.filter{!$0.isDeleted && $0.current.outOfBed >= store.now.addingTimeInterval(-30*86400)}.compactMap{$0.current.qualityRating}
                if !ratings.isEmpty { Surface { Text("How sleep felt").font(.headline); Text("\((Double(ratings.reduce(0,+))/Double(ratings.count)).formatted(.number.precision(.fractionLength(1)))) / 5 average quality").font(.title2); Text("\(ratings.count) diary ratings in the last 30 days").font(.caption).foregroundStyle(.secondary) } }
            }
            SectionTitle(title:"Habits & sleep",subtitle:"Association does not establish cause")
            if tags.isEmpty { Text("Add tags such as Exercise, Late caffeine or Stress to your diary. Comparisons need three tagged and three untagged main-sleep entries.").foregroundStyle(.secondary) }
            ForEach(tags,id:\.self) { tag in
                Surface {
                    Text(tag).font(.headline)
                    if let c=SleepInsights.habit(tag,diaries:store.data.diaries) {
                        LabeledContent("With tag · \(c.withCount) entries",value:Luma.duration(c.withMean*3600))
                        LabeledContent("Without tag · \(c.withoutCount) entries",value:Luma.duration(c.withoutMean*3600))
                        Text("Average reported duration per main-sleep entry, not a controlled experiment. Split-sleep entries and other habits can skew this comparison.").font(.caption).foregroundStyle(.secondary)
                    } else { Text("Needs at least three entries in each group.").foregroundStyle(.secondary) }
                }
            }
            NavigationLink("How Lotus calculates insights") { CalculationGuideView() }
        }.navigationTitle("Insights").navigationBarTitleDisplayMode(.inline)
    }
}
