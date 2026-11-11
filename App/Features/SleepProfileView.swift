import SwiftUI

struct SleepProfileView:View {
    @EnvironmentObject private var store:AppStore
    var body:some View {
        LumaPage {
            SectionTitle(title:"Your rhythm. Your way.",subtitle:"Get to know your sleep habits and what helps you unwind.")
            if let profile=store.data.profile {
                SleepProfileSummary(profile:profile)
                NavigationLink("Retake or edit my questionnaire") { SleepProfileQuiz() }.buttonStyle(.borderedProminent)
                Text("Last updated \(profile.updatedAt.formatted(date:.abbreviated,time:.omitted)). You can change every answer.").font(.caption).foregroundStyle(.secondary)
            } else {
                Surface {
                    Label("About 3 minutes",systemImage:"clock")
                    Text("Your schedule, evening habits, sound preferences and caffeine sensitivity help personalize your plan. Every answer stays on this iPhone.")
                    Text("This is an original reflection questionnaire, not a validated personality test or a measurement of your internal body clock.").font(.caption).foregroundStyle(.secondary)
                }
                NavigationLink("Get to know my sleep") { SleepProfileQuiz() }.buttonStyle(.borderedProminent)
            }
            NavigationLink("Caffeine guidance & log") { CaffeineView() }
            NavigationLink("Choose relaxing sounds") { RelaxationView() }
        }.navigationTitle("My sleep profile").navigationBarTitleDisplayMode(.inline)
    }
}
struct SleepProfileSummary:View {
    let profile:SleepProfile
    private func clock(_ minutes:Double)->String { let value=(Int(minutes.rounded())+1440)%1440;return String(format:"%02d:%02d",value/60,value%60) }
    var body:some View {
        let estimate=BodyClockEstimate.estimate(profile)
        Surface {
            Eyebrow(text:"Your wind-down style")
            Text(profile.windDownStyle).font(.title2.weight(.semibold))
            Text(profile.suggestion)
            LabeledContent("Evening energy, by your report",value:profile.reflectionScores[4] >= 3 ? "Often more alert" : profile.reflectionScores[4] <= 1 ? "Rarely more alert" : "Sometimes more alert")
            LabeledContent("Sound preference",value:profile.reflectionScores[3] >= 3 ? "Usually prefer silence" : "Open to trying quiet audio")
            Text("A description of your answers, not a fixed personality type.").font(.caption).foregroundStyle(.secondary)
        }
        Surface {
            Eyebrow(text:"Body-clock estimate")
            Text(estimate.tendency).font(.title2.weight(.semibold))
            LabeledContent("Free-day sleep midpoint",value:clock(estimate.freeMidpointMinutes))
            if let midpoint=estimate.adjustedMidpointMinutes { LabeledContent("Adjusted midpoint",value:clock(midpoint)) }
            if let shift=estimate.scheduleShiftMinutes { LabeledContent("Work/free-day timing gap",value:Luma.duration(shift*60)) }
            Text(estimate.explanation).font(.subheadline).foregroundStyle(.secondary)
            Text("Your goal: \(profile.goal.rawValue.lowercased()).").font(.subheadline)
            DisclosureGroup("How the estimate works") {
                Text("We find the midpoint of your reported free-day sleep and subtract half of any sleep duration above your weighted weekly average. Labels use transparent product cutoffs: before 03:00 earlier, 03:00–04:59 middle, 05:00 onward later. This is not a validated scoring instrument. An alarm on free days, no free days, or shift work disables the adjusted label. These answers do not change your sleep-duration target.").font(.caption).foregroundStyle(.secondary)
                Link("Questionnaire limits · NIMH",destination:URL(string:"https://www.nimh.nih.gov/about/advisory-boards-and-groups/namhc/reports/behavioral-assessment-methods-for-rdoc-constructs")!).font(.caption)
            }
        }
    }
}
struct SleepProfileQuiz:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile=SleepProfile()
    @State private var age="13–17"
    @State private var step=0
    @State private var loaded=false
    @State private var applyWakeTimes=false
    @State private var error:String?
    private let questions=["My thoughts stay busy at bedtime.","Small sounds interrupt my rest.","A familiar routine helps me unwind.","I prefer silence to background sound.","I feel more alert in the evening than in the morning."]
    private let frequency=["Never","Rarely","Sometimes","Often","Usually"]
    private let titles=["About you","Your usual sleep","Your wind-down style","Caffeine context","Your profile"]
    private func time(_ key:WritableKeyPath<SleepProfile,Int>)->Binding<Date> {
        Binding(get:{let minutes=profile[keyPath:key];return Calendar.current.date(bySettingHour:minutes/60,minute:minutes%60,second:0,of:Date()) ?? Date()},set:{date in let c=Calendar.current.dateComponents([.hour,.minute],from:date);profile[keyPath:key]=(c.hour ?? 0)*60+(c.minute ?? 0)})
    }
    var body:some View {
        Form {
            Section { ProgressView(value:Double(step+1),total:5);Text("\(step+1) of 5 · \(titles[step])").font(.caption) }
            if step == 0 {
                Section("What matters to you?") {
                    Picker("Main goal",selection:$profile.goal) { ForEach(SleepGoal.allCases,id:\.self){Text($0.rawValue).tag($0)} }
                    Picker("Age guidance",selection:$age) { ForEach(["13–17","18–60","61–64","65+"],id:\.self){Text($0).tag($0)} }
                    Text("Age affects sleep-duration guidance and caffeine advice. No name, birth date, weight or account is required.").font(.caption).foregroundStyle(.secondary)
                }
            } else if step == 1 {
                Section("A usual week · your local clock") {
                    DatePicker("Work/school: fall asleep",selection:time(\.workSleepMinutes),displayedComponents:.hourAndMinute)
                    DatePicker("Work/school: wake up",selection:time(\.workWakeMinutes),displayedComponents:.hourAndMinute)
                    DatePicker("Free day: fall asleep",selection:time(\.freeSleepMinutes),displayedComponents:.hourAndMinute)
                    DatePicker("Free day: wake up",selection:time(\.freeWakeMinutes),displayedComponents:.hourAndMinute)
                    Stepper("\(profile.workDays) work/school days per week",value:$profile.workDays,in:0...7)
                    Toggle("I use an alarm on free days",isOn:$profile.freeDayAlarm)
                    Toggle("I work nights or rotating shifts",isOn:$profile.shiftWork)
                    Text("Use your usual main sleep, including sleep across midnight. These are remembered averages, not measured times. Split sleep is better represented in your diary.").font(.caption).foregroundStyle(.secondary)
                }
            } else if step == 2 {
                Section("What feels like you?") {
                    ForEach(questions.indices,id:\.self) { i in
                        VStack(alignment:.leading,spacing:5) {
                            Text(questions[i])
                            Picker("Your answer",selection:Binding(get:{profile.reflectionScores[i]},set:{profile.reflectionScores[i]=$0})) { ForEach(0..<5,id:\.self){Text(frequency[$0]).tag($0)} }
                        }
                    }
                    Text("These original questions describe habits and preferences. They do not assess mental health, personality disorders or intelligence.").font(.caption).foregroundStyle(.secondary)
                }
            } else if step == 3 {
                Section("Your caffeine context") {
                    Picker("Sensitivity",selection:$profile.caffeineSensitivity) { ForEach(CaffeineSensitivity.allCases,id:\.self){Text($0.rawValue).tag($0)} }
                    if age == "13–17" {
                        Text("For under-18s, avoiding caffeine is the recommended choice. Lotus can log what you have already had and remind you to choose caffeine-free drinks; it does not recommend a dose.")
                    } else {
                        Text("Do pregnancy, breastfeeding, a medical condition, medicines, or advice to limit caffeine apply? You do not need to give details.").font(.subheadline)
                        Picker("Context",selection:$profile.caffeineContext) { ForEach(CaffeineContext.allCases,id:\.self){Text($0.rawValue).tag($0)} }
                        if profile.caffeineContext == .standard {
                            Picker("My optional tracking cap",selection:Binding(get:{profile.personalCaffeineCapMG.map{Int($0)} ?? -1},set:{profile.personalCaffeineCapMG=$0 < 0 ? nil : Double($0)})) {
                                Text("No personal cap").tag(-1)
                                ForEach(Array(stride(from:0,through:400,by:50)),id:\.self){Text("\($0) mg/day").tag($0)}
                            }
                            Text("Your chosen cap is not a calculated safe dose. The general adult reference of 400 mg is not a goal, and some people need much less.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Lotus uses an 8-hour pre-bed buffer for usual sensitivity and 10 hours for sensitive or uncertain responses. The extra two hours are a conservative app setting, not a measured clearance time.").font(.caption).foregroundStyle(.secondary)
                    Link("Caffeine guidance · FDA",destination:URL(string:"https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much")!)
                }
            } else {
                Section { SleepProfileSummary(profile:profile) }
                Section("Apply to your plan") {
                    Toggle("Use these wake times in Plan",isOn:$applyWakeTimes)
                    Text("Uses work/school wake time for Monday–Friday and free-day wake time for Saturday–Sunday. Your sleep target stays unchanged, except a teen target cannot be below 8 hours. Reapply notifications after saving changes.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section {
                if step < 4 { Button("Continue") {
                    do { if step == 1 { try profile.validate() };error=nil;step+=1 } catch { self.error=error.localizedDescription }
                } } else { Button("Save my profile") { save() } }
                if step > 0 { Button("Previous") { error=nil;step-=1 } }
            }
        }.navigationTitle(titles[step]).navigationBarTitleDisplayMode(.inline)
            .onAppear { guard !loaded else{return};loaded=true;profile=store.data.profile ?? SleepProfile();age=store.data.preferences.ageBand }
    }
    private func save() {
        do {
            profile.updatedAt=store.now
            if age == "13–17" || profile.caffeineContext != .standard { profile.personalCaffeineCapMG=nil }
            try profile.validate()
            try store.transact { data in
                data.profile=profile;data.preferences.ageBand=age
                if age == "13–17" { data.preferences.targetHours=max(8,data.preferences.targetHours) }
                if applyWakeTimes { data.preferences.weekdayWakeMinutes=profile.workWakeMinutes;data.preferences.weekendWakeMinutes=profile.freeWakeMinutes }
            }
            dismiss()
        } catch { self.error=error.localizedDescription }
    }
}
