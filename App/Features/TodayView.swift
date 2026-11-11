import SwiftUI
import Charts
struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        LumaPage {
            HStack { Eyebrow(text:store.now.formatted(.dateTime.weekday(.wide).month().day())); Spacer(); Image(systemName:"sparkle").foregroundStyle(Luma.warm).accessibilityHidden(true) }
            VStack(alignment:.leading,spacing:8) { Text("Your sleep.\nYour everyday rhythm.").font(.system(.largeTitle,design:.rounded,weight:.semibold)); Text("Your sleep, in perspective.").foregroundStyle(.secondary) }
            sleepHero
            if store.data.activeSession != nil {
                PrimaryButton(title:"Return to bedtime",symbol:"moon.zzz") { store.selectedTab=1 }
            } else {
                PrimaryButton(title:store.data.diaries.contains(where:{$0.current.sleepStart == nil && !$0.isDeleted}) ? "Review your night" : "Track your sleep",symbol:"moon.zzz") { store.selectedTab=1 }
            }
            if store.data.preferences.showCompanion ?? true { RestCompanionCard() }
            NavigationLink { MorningInboxView() } label: {
                Surface {
                    HStack { Label("Morning inbox",systemImage:"tray").font(.headline);Spacer();Image(systemName:"chevron.right") }
                    let pending=store.data.morningTasks.filter{$0.completedAt == nil}
                    Text(pending.isEmpty ? "Leave yourself a practical note for after waking." : "\(pending.filter{$0.isDue(at:store.now)}.count) ready · \(pending.count) unfinished").font(.subheadline).foregroundStyle(.secondary)
                }
            }.buttonStyle(.plain)
            if let day=store.days.last(where:{$0.hours != nil || !$0.sleep.inBed.isEmpty}) {
                NavigationLink { NightRewindView(day:day) } label: { Label("Rewind your latest recorded night",systemImage:"clock.arrow.circlepath") }
            }
            shortfall
            energy
            NavigationLink { PlanningView() } label: {
                Surface {
                    HStack { Eyebrow(text:"Tonight, made simple"); Spacer(); Image(systemName:"arrow.up.right") }
                    Text(store.plan.windDown,style:.time).font(.system(.largeTitle,design:.rounded,weight:.medium)).foregroundStyle(Luma.warm)
                    Text("Start winding down").font(.headline)
                    Text("Bed \(store.plan.bedtime.formatted(date:.omitted,time:.shortened))  ·  Wake \(store.plan.wake.formatted(date:.omitted,time:.shortened))").font(.subheadline).foregroundStyle(.secondary)
                }
            }.buttonStyle(.plain)
            CheckInView()
            SectionTitle(title:"Made for your evenings")
            NavigationLink { RelaxationView() } label: { Label("Relaxing sounds & your own MP3s",systemImage:"speaker.wave.2") }
            NavigationLink { SleepExperimentsView() } label: { Label("Sleep experiments",systemImage:"chart.bar.xaxis") }
            NavigationLink { CaffeineView() } label: { Label("Caffeine guidance & cutoff",systemImage:"cup.and.saucer") }
            NavigationLink { SleepProfileView() } label: { Label(store.data.profile == nil ? "Get to know your sleep" : "Your sleep profile",systemImage:"person.crop.circle") }
        }.navigationTitle("Today").navigationBarTitleDisplayMode(.inline).onAppear{store.refreshCompanion()}
    }
    private var sleepHero:some View {
        Surface {
            Eyebrow(text:"Current sleep day")
            if let h=store.days.last?.hours {
                ViewThatFits(in:.horizontal) {
                    HStack(spacing:24) { ring(hours:h); summary(hours:h) }
                    VStack(alignment:.leading,spacing:18) { ring(hours:h); summary(hours:h) }
                }
                Text("Includes confirmed naps before \(store.data.preferences.boundaryHour):00. Grouped in \(store.data.preferences.reportingTimeZoneID).").font(.caption).foregroundStyle(.secondary)
            } else {
                EmptyPanel(symbol:"moon.stars",title:"Your first night starts here",text:"Start a bedtime session or add a diary entry. Time in bed becomes estimated sleep only after your morning review.")
            }
        }
    }
    private func ring(hours:Double)->some View {
        ZStack {
            Circle().stroke(Luma.lavender.opacity(0.12),lineWidth:10)
            Circle().trim(from:0,to:min(1,hours/store.data.preferences.targetHours)).stroke(AngularGradient(colors:[Luma.blue,Luma.lavender],center:.center),style:StrokeStyle(lineWidth:10,lineCap:.round)).rotationEffect(.degrees(-90))
            Image(systemName:"moon.fill").font(.system(size:30,weight:.light)).foregroundStyle(Luma.lavender)
        }.frame(width:104,height:104).padding(5).accessibilityHidden(true)
    }
    private func summary(hours:Double)->some View {
        VStack(alignment:.leading,spacing:7) {
            Text(Luma.duration(hours*3600)).font(.system(.largeTitle,design:.rounded,weight:.semibold)).minimumScaleFactor(0.7)
            Text("of your \(store.data.preferences.targetHours.formatted())h target").foregroundStyle(.secondary)
            let qualities=Set(store.latestSleep.segments.map{$0.record.quality.rawValue}).sorted()
            Text(qualities.joined(separator:" · ").capitalized).font(.caption.weight(.medium)).foregroundStyle(Luma.lavender)
        }
    }
    private var shortfall:some View {
        let value=SleepInsights.shortfall(days:store.days,target:store.data.preferences.targetHours)
        return VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.firstTextBaseline) { Text("Recent shortfall").font(.headline); Spacer(); Text(value.observedDays == 0 ? "—" : Luma.duration(value.hours*3600)).font(.title3.weight(.semibold)).foregroundStyle(Luma.warm) }
            Text("\(value.observedDays) of 14 days have recorded sleep. Missing days are unknown. Today's total may change.").font(.subheadline).foregroundStyle(.secondary)
            NavigationLink("How this is calculated") { CalculationGuideView() }.font(.subheadline)
        }
    }
    private var energy:some View {
        let wake=store.latestSleep.segments.filter{$0.record.stage.isAsleep && $0.record.kind != .nap}.last?.end
        let points=wake.map { SleepInsights.energy(wake:$0,days:store.days,target:store.data.preferences.targetHours,checkIns:store.data.checkIns) } ?? []
        return VStack(alignment:.leading,spacing:14) {
            SectionTitle(title:"A rhythm for your day",subtitle:"A planning estimate, not a measurement")
            if points.isEmpty { Text("Log at least three days of sleep to see a preliminary curve. A few energy check-ins will help put it in context.").foregroundStyle(.secondary) }
            else {
                Chart(points) { p in
                    AreaMark(x:.value("Time",p.date),yStart:.value("Baseline",1),yEnd:.value("Estimated alertness",p.value)).foregroundStyle(LinearGradient(colors:[Luma.lavender.opacity(0.30),Luma.lavender.opacity(0.01)],startPoint:.top,endPoint:.bottom)).interpolationMethod(.catmullRom)
                    LineMark(x:.value("Time",p.date),y:.value("Estimated alertness",p.value)).foregroundStyle(Luma.lavender).lineStyle(StrokeStyle(lineWidth:3)).interpolationMethod(.catmullRom)
                }.chartYScale(domain:1...5).chartYAxis(.hidden).frame(height:155)
                Text("Assumes a usual rise after waking, a possible mid-day dip and a later decline. Use how you actually feel to guide your plans.").font(.caption).foregroundStyle(.secondary)
                NavigationLink("Model assumptions") { CalculationGuideView() }.font(.subheadline)
            }
        }
    }
}
struct CheckInView: View {
    @EnvironmentObject private var store:AppStore
    var body:some View {
        Surface {
            SectionTitle(title:"How's your energy?",subtitle:"A quick check-in, from low to high")
            HStack { ForEach(1...5,id:\.self) { value in Button { store.checkIn(value); Luma.haptic() } label: { Text("\(value)").font(.headline).frame(maxWidth:.infinity,minHeight:44) }.buttonStyle(.bordered).accessibilityLabel("Energy \(value) out of 5") } }
            if let last=store.data.checkIns.last { Text("Last check-in: \(last.value)/5 · \(last.date.formatted(date:.abbreviated,time:.shortened))").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct CalculationGuideView: View {
    var body:some View {
        LumaPage {
            SectionTitle(title:"Clear inputs. Honest estimates.")
            Surface { Text("14-day shortfall").font(.headline); Text("For each day with recorded sleep: max(0, target − recorded sleep). Add those shortfalls over 14 sleep days. Confirmed naps count in their sleep day; extra hours on another day do not subtract from the total. Missing days are excluded. Sparse records can undercount sleep, so check coverage before interpreting this number.") }
            Surface { Text("Sleep day & efficiency").font(.headline); Text("Sleep days end at your chosen boundary in your reporting timezone. Intervals crossing the boundary are split by elapsed time. This supports overnight and irregular schedules. Efficiency is shown only when all counted sleep falls within recorded time in bed. Gaps remain unknown.") }
            Surface { Text("Energy curve").font(.headline); Text("The curve is an unvalidated planning heuristic. It starts from your latest main wake, assumes brief waking grogginess, a possible dip about seven hours later, and a decline after eleven hours. The last seven recorded totals can lower the curve modestly. Seven earlier check-ins allow a small overall adjustment. The model does not measure circadian phase, melatonin, sleep need, readiness or performance.") }
            Text("Shortfall is not exact biological debt. Avoid restricting sleep to improve a chart. Consistent opportunities for enough sleep matter more than any single number.").foregroundStyle(.secondary)
            Link("Sleep guidance · CDC",destination:URL(string:"https://www.cdc.gov/sleep/about/index.html")!)
        }.navigationTitle("Behind the numbers").navigationBarTitleDisplayMode(.inline)
    }
}
