import SwiftUI

struct NotificationsView:View {
    @EnvironmentObject private var store:AppStore
    var body:some View { NotificationSettingsContent(service:store.reminders) }
}
private struct NotificationSettingsContent:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var service:ReminderService
    @State private var busy=false
    @State private var result:String?
    private func option(_ key:WritableKeyPath<ReminderOptions,Bool>)->Binding<Bool> {
        Binding(get:{(store.data.preferences.reminderOptions ?? ReminderOptions())[keyPath:key]},set:{value in store.updatePreferences { p in var options=p.reminderOptions ?? ReminderOptions();options[keyPath:key]=value;p.reminderOptions=options }})
    }
    private var scheduleChanged:Bool { store.data.preferences.remindersEnabled && store.data.preferences.remindersFingerprint != ReminderPlanner.fingerprint(preferences:store.data.preferences,profile:store.data.profile) }
    var body:some View {
        Form {
            Section("Notification access") {
                Label(service.permission,systemImage:service.canDeliver ? "bell.badge" : "bell.slash")
                Button("Send a test in 5 seconds") { run { try await service.test(); result="Test scheduled. Watch for a banner, or lock your phone to check delivery." } }
                Button("Open iPhone notification settings") { if let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                Text("Focus, Silent Mode and iOS notification settings can mute or delay reminders. These are ordinary local notifications, not wake alarms. No server or internet connection is required after scheduling.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Choose your weekly reminders") {
                Toggle("Wind-down time",isOn:option(\.windDown))
                Toggle("Planned bedtime",isOn:option(\.bedtime))
                Toggle("Caffeine cutoff",isOn:option(\.caffeine))
                Text("Caffeine cutoff: \(CaffeineAdvice.cutoffHours(store.data.profile)) hours before planned bedtime. This is a planning buffer, not a measurement of your metabolism or permission to consume caffeine earlier.").font(.caption).foregroundStyle(.secondary)
                if scheduleChanged { Label("Your settings changed. Apply reminders to update the scheduled times.",systemImage:"arrow.triangle.2.circlepath").foregroundStyle(Luma.warm) }
                Button("Apply selected reminders") { run {
                    try await service.install(preferences:store.data.preferences,profile:store.data.profile)
                    let fingerprint=ReminderPlanner.fingerprint(preferences:store.data.preferences,profile:store.data.profile)
                    let enabled = !ReminderPlanner.weekly(preferences:store.data.preferences,profile:store.data.profile,after:store.now).isEmpty
                    try store.transact{$0.preferences.remindersEnabled=enabled;$0.preferences.remindersFingerprint=fingerprint}
                    result=enabled ? "Weekly reminders scheduled. Reapply after changing your schedule, timezone or caffeine profile." : "Weekly reminders removed. Any separate habit reminder stays scheduled."
                } }
                Button("Turn off all reminders",role:.destructive) {
                    guard !store.isDemo else { result="Scheduling is disabled in demo mode.";return }
                    do { try store.cancelReminders();result="All Lotus notifications removed. Morning notes stay in your inbox." } catch { result=error.localizedDescription }
                }
                NavigationLink("Change wake times & bedtime plan") { PlanningView() }
                NavigationLink("Caffeine guidance & log") { CaffeineView() }
            }
            Section("Next scheduled notifications") {
                if service.scheduled.isEmpty { Text("Nothing scheduled yet.").foregroundStyle(.secondary) }
                ForEach(service.scheduled) { item in VStack(alignment:.leading,spacing:4) { Text(item.title); if let date=item.nextDate { Text(date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary) } } }
                Text("Times here are shown in this iPhone’s timezone. Weekly reminders follow your reporting timezone.").font(.caption).foregroundStyle(.secondary)
            }
            if busy { ProgressView("Updating notifications…") }
            if let result { Section { Text(result) } }
        }.navigationTitle("Notifications").disabled(busy)
            .task { await service.refresh() }
            .onChange(of:scenePhase) { _,value in if value == .active { Task { await service.refresh() } } }
    }
    private func run(_ action:@escaping() async throws->Void) {
        guard !store.isDemo else { result="Scheduling is disabled in demo mode.";return }
        busy=true;Task { defer{busy=false};do{try await action()}catch{result=error.localizedDescription} }
    }
}
