import SwiftUI
struct HistoryView:View {
    @EnvironmentObject private var store:AppStore
    @State private var weeksAgo=0
    private func quality(for day:SleepDay)->Double? {
        let values=store.data.diaries.filter { !$0.isDeleted && $0.current.kind != .nap && $0.current.wake >= day.window.start && $0.current.wake < day.window.end }.compactMap{$0.current.qualityRating}
        return values.isEmpty ? nil : Double(values.reduce(0,+))/Double(values.count)
    }
    var body:some View {
        let calendar=SleepCalendar.calendar(zoneID:store.data.preferences.reportingTimeZoneID)
        let ending=calendar.date(byAdding:.day,value:-7*weeksAgo,to:store.now) ?? store.now
        let days=SleepCalendar.days(records:store.data.effectiveRecords,endingOn:ending,count:7,preferences:store.data.preferences)
        let target=store.data.preferences.targetHours
        let ratings=Dictionary(uniqueKeysWithValues:days.map { ($0.date,NightReview.rating(hours:$0.hours,target:target,quality:quality(for:$0))) })
        let known=days.compactMap(\.hours)
        LumaPage {
            SectionTitle(title:weeksAgo == 0 ? "Your last seven days." : "A week in perspective.",subtitle:"See what went well and which nights need attention.")
            HStack {
                Button { weeksAgo+=1 } label: { Image(systemName:"chevron.left").frame(width:44,height:44) }.accessibilityLabel("Previous seven days")
                Spacer()
                Text("\(Luma.day(days[0].date,zoneID:store.data.preferences.reportingTimeZoneID,short:true)) – \(Luma.day(days[6].date,zoneID:store.data.preferences.reportingTimeZoneID,short:true))").font(.subheadline.weight(.medium))
                Spacer()
                Button { weeksAgo=max(0,weeksAgo-1) } label: { Image(systemName:"chevron.right").frame(width:44,height:44) }.disabled(weeksAgo == 0).accessibilityLabel("Next seven days")
            }
            Surface {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:5) { Eyebrow(text:"Average sleep"); Text(known.isEmpty ? "—" : Luma.duration(known.reduce(0,+)/Double(known.count)*3600)).font(.title.bold()); Text("\(known.count) of 7 days logged").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    VStack(alignment:.trailing,spacing:5) { Text("\(ratings.values.filter{$0 == .good}.count)").font(.title.bold()).foregroundStyle(NightRating.good.tint); Text("good days").font(.caption); Text("Target: \(target.formatted())h").font(.caption).foregroundStyle(.secondary) }
                }
                SleepBarChart(days:days,target:target,zoneID:store.data.preferences.reportingTimeZoneID,ratings:ratings)
                Text("Green: good · amber: mixed · coral: needs attention. A cross means no confirmed sleep, not zero sleep.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(days.reversed()) { day in
                let rating=ratings[day.date] ?? .unlogged
                NavigationLink { DayDetailView(day:day) } label: {
                    Surface {
                        HStack(alignment:.top) {
                            VStack(alignment:.leading,spacing:7) {
                                Text(Luma.day(day.date,zoneID:store.data.preferences.reportingTimeZoneID)).font(.headline)
                                Label(rating.rawValue,systemImage:rating.symbol).font(.subheadline.weight(.semibold)).foregroundStyle(rating.tint)
                            }
                            Spacer()
                            Text(day.hours.map{Luma.duration($0*3600)} ?? "—").font(.title3.weight(.semibold))
                            Image(systemName:"chevron.right").font(.caption).padding(.top,5)
                        }
                        Text(NightReview.explanation(hours:day.hours,target:target,quality:quality(for:day))).font(.caption).foregroundStyle(.secondary)
                        if day.napHours > 0 { Text("Includes \(Luma.duration(day.napHours*3600)) of naps").font(.caption).foregroundStyle(.secondary) }
                        let wakeups=store.data.disturbances.filter{$0.start >= day.window.start && $0.start < day.window.end}.count
                        if wakeups > 0 { Label("\(wakeups) logged wake-up\(wakeups == 1 ? "" : "s")",systemImage:"moon.zzz").font(.caption) }
                    }
                }.buttonStyle(.plain)
            }
            DisclosureGroup("How these labels work") {
                Text("Good: within 30 minutes of your duration target or above it, with quality 4–5 if rated. Needs attention: more than an hour below target or quality 1–2. Other logged days are mixed. Missing days are not scored. These are diary summaries, not medical scores; extra hours do not prove better sleep.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("History").navigationBarTitleDisplayMode(.inline)
    }
}
struct DayDetailView:View {
    @EnvironmentObject private var store:AppStore
    let day:SleepDay
    @State private var editing:DiaryEntry?
    @State private var correction=false
    var records:[SleepRecord] { store.data.effectiveRecords.filter{$0.start < day.window.end && $0.end > day.window.start} }
    var resolved:ResolvedSleep { SleepReconciler.resolve(records,priority:store.data.preferences.sourcePriority,within:day.window) }
    var body:some View {
        LumaPage {
            SectionTitle(title:Luma.day(day.date,zoneID:store.data.preferences.reportingTimeZoneID),subtitle:"\(Luma.duration(resolved.asleepSeconds)) recorded sleep")
            NavigationLink { NightRewindView(day:day) } label: { Label("Night Rewind",systemImage:"clock.arrow.circlepath") }
            if !resolved.segments.isEmpty { StageTimeline(sleep:resolved) }
            ForEach(store.data.disturbances.filter{$0.start >= day.window.start && $0.start < day.window.end}) { entry in
                Surface {
                    Label(entry.reason.title,systemImage:"moon.zzz").font(.headline)
                    Text("Wake-up logged at \(entry.start.formatted(date:.omitted,time:.shortened))").font(.subheadline)
                    Text(entry.end.map { "Returned to rest at \($0.formatted(date:.omitted,time:.shortened))" } ?? "End time not recorded").font(.caption).foregroundStyle(.secondary)
                    if !entry.notes.isEmpty { Text(entry.notes).font(.subheadline) }
                    Text("Wake-up logs are added to sleep totals only when you include them in the diary review.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Surface {
                LabeledContent("Recorded time in bed",value:resolved.inBedSeconds > 0 ? Luma.duration(resolved.inBedSeconds) : "Unknown")
                LabeledContent("Sleep efficiency",value:resolved.efficiency.map{($0*100).formatted(.number.precision(.fractionLength(0)))+"%"} ?? "Not enough evidence")
                Text("Times are displayed in this iPhone’s local timezone. Source timezone labels preserve available provenance.").font(.caption).foregroundStyle(.secondary)
                Text("Sources: \(Set(records.map(\.sourceName)).sorted().joined(separator:", "))").font(.footnote).foregroundStyle(.secondary)
                if resolved.segments.contains(where:{$0.hasConflict}) { Text("Overlapping records disagree. Your source order resolves each interval. Original records remain available below.").font(.footnote).foregroundStyle(Luma.warm) }
            }
            ForEach(store.data.diaries.filter{!$0.isDeleted && $0.current.bedtime < day.window.end && $0.current.outOfBed > day.window.start}) { entry in
                Surface {
                    HStack { Text(entry.current.kind == .nap ? "Nap diary" : "Sleep diary").font(.headline); Spacer(); if let q=entry.current.qualityRating { Text("Quality \(q)/5").font(.caption) } }
                    if !entry.current.notes.isEmpty { Text(entry.current.notes) }
                    if !entry.current.tags.isEmpty { Text(entry.current.tags.joined(separator:" · ")).font(.subheadline).foregroundStyle(.secondary) }
                    Button("Edit or review") { editing=entry }
                    if entry.versions.count>1 { Button("Undo last edit") { store.perform { try store.transact { s in if let i=s.diaries.firstIndex(where:{$0.id == entry.id}) { s.diaries[i].undoRevision() } } } } }
                    Button("Hide this diary entry",role:.destructive) { store.perform { try store.transact { s in if let i=s.diaries.firstIndex(where:{$0.id == entry.id}) { s.diaries[i].isDeleted=true } } } }
                }
            }
            if !records.isEmpty { Button("Correct these source records",systemImage:"pencil") { correction=true }; Text("This replaces the entire source intervals shown below, including portions outside this sleep day, with your reported window. Originals are preserved. Use separate diary entries for split sleep.").font(.caption).foregroundStyle(.secondary) }
            DisclosureGroup("Source records") {
                ForEach(records) { record in VStack(alignment:.leading,spacing:4) { Text("\(record.stage.label) · \(record.sourceName)").font(.subheadline.weight(.medium)); Text("\(record.start.formatted(date:.abbreviated,time:.shortened)) – \(record.end.formatted(date:.abbreviated,time:.shortened))").font(.caption); Text("\(record.quality.rawValue.capitalized) · Source zone: \(record.timeZoneID)").font(.caption).foregroundStyle(.secondary) }.padding(.vertical,6) }
            }
            NavigationLink("Revisions & hidden entries") { RevisionsView() }
        }.navigationTitle("Sleep detail").navigationBarTitleDisplayMode(.inline)
        .sheet(item:$editing) { DiaryEditor(version:$0.current,entryID:$0.id) }
        .sheet(isPresented:$correction) {
            let start=records.map(\.start).min() ?? day.window.start
            let end=records.map(\.end).max() ?? day.window.end
            DiaryEditor(version:DiaryVersion(bedtime:start,sleepStart:start,wake:end,outOfBed:end,timeZoneID:store.data.preferences.reportingTimeZoneID),replacing:records.map(\.id))
        }
    }
}
struct RevisionsView:View {
    @EnvironmentObject private var store:AppStore
    var body:some View {
        List {
            Section("Corrections") {
                if store.data.corrections.isEmpty { Text("No corrections yet.") }
                ForEach(store.data.corrections.reversed()) { c in
                    VStack(alignment:.leading,spacing:8) { Text(c.reason); Text(c.createdAt,style:.date).font(.caption); Button(c.isUndone ? "Apply again" : "Undo correction") { store.perform { try store.transact { s in if let i=s.corrections.firstIndex(where:{$0.id == c.id}) { s.corrections[i].isUndone.toggle() } } } } }
                }
            }
            Section("Hidden diary entries") {
                ForEach(store.data.diaries.filter(\.isDeleted)) { d in Button("Restore \(d.current.bedtime.formatted(date:.abbreviated,time:.shortened))") { store.perform { try store.transact { s in if let i=s.diaries.firstIndex(where:{$0.id == d.id}) { s.diaries[i].isDeleted=false } } } } }
            }
        }.navigationTitle("Revisions")
    }
}
