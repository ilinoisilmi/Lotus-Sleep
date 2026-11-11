import SwiftUI
struct PlanningView:View {
    @EnvironmentObject private var store:AppStore
    @State private var alarmDate=Date().addingTimeInterval(9*3600)
    @State private var habitDate=Date().addingTimeInterval(3600)
    @State private var habit="Start a relaxing routine"
    @State private var working=false
    @State private var result:String?
    private func timeBinding(_ key:WritableKeyPath<Preferences,Int>)->Binding<Date> {
        Binding(get:{ let m=store.data.preferences[keyPath:key]; return Calendar.current.date(bySettingHour:m/60,minute:m%60,second:0,of:Date())! },set:{ date in let c=Calendar.current.dateComponents([.hour,.minute],from:date); store.updatePreferences{$0[keyPath:key]=(c.hour ?? 0)*60+(c.minute ?? 0)} })
    }
    var body:some View {
        Form {
            Section("Wake commitments") {
                DatePicker("Weekdays",selection:timeBinding(\.weekdayWakeMinutes),displayedComponents:.hourAndMinute)
                DatePicker("Weekends",selection:timeBinding(\.weekendWakeMinutes),displayedComponents:.hourAndMinute)
                Stepper("Wind-down: \(store.data.preferences.windDownMinutes) min",value:Binding(get:{store.data.preferences.windDownMinutes},set:{value in store.updatePreferences{$0.windDownMinutes=value}}),in:0...180,step:15)
                Stepper("Time to settle: \(store.data.preferences.settlingMinutes) min",value:Binding(get:{store.data.preferences.settlingMinutes},set:{value in store.updatePreferences{$0.settlingMinutes=value}}),in:0...120,step:5)
                Text("Weekends are Saturday and Sunday. Weekly wake times use your reporting timezone. Plan summaries and the fixed alarm picker show this iPhone’s local time. For irregular schedules, choose a specific date below.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Tonight's plan") {
                LabeledContent("Wind down",value:store.plan.windDown.formatted(date:.abbreviated,time:.shortened))
                LabeledContent("Go to bed",value:store.plan.bedtime.formatted(date:.abbreviated,time:.shortened))
                LabeledContent("Wake",value:store.plan.wake.formatted(date:.abbreviated,time:.shortened))
                NavigationLink("Notifications · bedtime, wind-down & caffeine") { NotificationsView() }
                Button("Turn off all reminders") { guard !store.isDemo else { result="Scheduling is disabled in demo mode."; return }; do { try store.cancelReminders(); result="Lotus reminders removed. Morning notes stay in your inbox." } catch { result=error.localizedDescription } }
                Text("Reminders are ordinary notifications. They may be muted and do not replace a wake alarm.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Wake alarm · choose a specific date") {
                DatePicker("Wake time",selection:$alarmDate,in:Date()...)
                let plan=SleepPlanner.plan(wake:alarmDate,preferences:store.data.preferences)
                Text("For this wake time: bed at \(plan.bedtime.formatted(date:.abbreviated,time:.shortened)), wind down at \(plan.windDown.formatted(date:.abbreviated,time:.shortened)).").font(.caption)
                if store.isDemo { Text("Demo mode · no real alarm actions") } else { AlarmStatusView(service:store.alarms) }
                Button("Schedule wake alarm") { run { try await store.alarms.schedule(at:alarmDate); result="Wake alarm scheduled in iOS." } }
                Button("Cancel Lotus wake alarm",role:.destructive) { run { try await store.alarms.cancel(); result="Lotus wake alarm cancelled." } }
                if !store.alarms.supported { Text("On iOS 17–18, set your alarm in Apple's Clock app. Lotus cannot create an equivalent system wake alarm on those versions.").foregroundStyle(.secondary) }
                Text("One fixed wake alarm at a time. No light-sleep detection or smart wake. Test alarm delivery on your iPhone before relying on it.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Optional habit reminder") {
                TextField("Reminder",text:$habit)
                DatePicker("When",selection:$habitDate,in:Date()...)
                Button("Schedule habit reminder") { run { try await store.reminders.habit(at:habitDate,title:habit); result="Habit reminder scheduled." } }
            }
            if working { ProgressView("Scheduling…") }
            if let result { Section { Text(result) } }
        }.navigationTitle("Plan your rest").disabled(working)
        .onAppear { alarmDate=store.plan.wake }
    }
    private func run(_ task:@escaping() async throws->Void) {
        guard !store.isDemo else { result="Scheduling is disabled in demo mode."; return }
        working=true; Task { defer{working=false}; do{try await task()}catch{result=error.localizedDescription} }
    }
}
struct AlarmStatusView:View {
    @ObservedObject var service:WakeAlarmService
    var body:some View { VStack(alignment:.leading) { Text(service.status); if let date=service.scheduledDate { Text(date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary) } }.task{await service.refresh()} }
}
