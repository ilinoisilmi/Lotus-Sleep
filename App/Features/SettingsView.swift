import SwiftUI
struct SettingsView:View {
    @EnvironmentObject private var store:AppStore
    private func binding<T>(_ keyPath:WritableKeyPath<Preferences,T>)->Binding<T> { Binding(get:{store.data.preferences[keyPath:keyPath]},set:{ value in store.updatePreferences{$0[keyPath:keyPath]=value} }) }
    var body:some View {
        Form {
            Section("Your rhythm") {
                NavigationLink("Morning inbox") { MorningInboxView() }
                NavigationLink("Rest streak & companions") { CompanionView() }
                NavigationLink("Sleep experiments") { SleepExperimentsView() }
                NavigationLink("My sleep profile & questionnaire") { SleepProfileView() }
                NavigationLink("Notifications") { NotificationsView() }
                NavigationLink("Caffeine guidance & log") { CaffeineView() }
                Stepper("Target: \(store.data.preferences.targetHours.formatted()) hours",value:binding(\.targetHours),in:(store.data.preferences.ageBand == "13–17" ? 8.0 : 7.0)...12,step:0.25)
                Picker("Age guidance",selection:binding(\.ageBand)) { Text("13–17").tag("13–17"); Text("18–60").tag("18–60"); Text("61–64").tag("61–64"); Text("65+").tag("65+") }
                Picker("Preferred method",selection:binding(\.preferredMethod)) { Text("Bedtime session").tag(TrackingMethod.bedtime); Text("Diary").tag(TrackingMethod.diary); Text("Health").tag(TrackingMethod.health); Text("Motion review").tag(TrackingMethod.motion); Text("File import").tag(TrackingMethod.file) }
                NavigationLink("Schedules, reminders & wake alarm") { PlanningView() }
                Picker("Sleep day ends",selection:binding(\.boundaryHour)) { ForEach(0..<24,id:\.self) { Text(String(format:"%02d:00",$0)).tag($0) } }
                NavigationLink { TimezonePicker() } label: { LabeledContent("Reporting timezone",value:store.data.preferences.reportingTimeZoneID) }
                Button("Use current timezone") { store.updatePreferences{$0.reportingTimeZoneID=TimeZone.current.identifier} }
                Text("Changing the boundary or timezone regroups existing intervals without changing their absolute timestamps. After changing a schedule, use Apply reminders to replace existing notifications.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Sources & permissions") {
                NavigationLink("Relaxing sounds & my MP3s") { RelaxationView() }
                NavigationLink("Apple Health & source priority") { HealthSourceView() }
                Button("Open iPhone app settings") { if let url=URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                NavigationLink("Sound monitoring & retention") { AudioView() }
                NavigationLink("Revisions & hidden entries") { RevisionsView() }
            }
            Section("Appearance") {
                Picker("Theme",selection:binding(\.appearance)) { Text("System").tag("system"); Text("Midnight").tag("dark"); Text("Daylight").tag("light") }
                #if HEALTH_ENABLED
                Toggle("Show tonight's plan in widget",isOn:binding(\.widgetEnabled))
                Text("The widget shares only your target and wind-down time with the extension. No diary notes, audio or sleep history are shared.").font(.caption)
                #else
                Text("The plan widget is available in the optional Health-enabled build.").font(.footnote).foregroundStyle(.secondary)
                #endif
            }
            Section("Your data") {
                NavigationLink("Export, restore & delete") { DataManagementView() }
                NavigationLink("Import a CSV or JSON sleep log") { ImportView() }
                NavigationLink("Privacy & storage") { PrivacyView() }
            }
            Section("Explore & understand") {
                Button(store.isDemo ? "Exit demo mode" : "Enter demo mode") { store.toggleDemo() }
                NavigationLink("Calculations & evidence") { CalculationGuideView() }
                NavigationLink("Compatibility & limitations") { CapabilitiesView() }
                Text("Lotus Sleep · 1.3 development build\niOS 17+ · Personal use").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Settings")
    }
}
struct PrivacyView:View {
    var body:some View {
        LumaPage {
            SectionTitle(title:"Your nights are personal.")
            Surface { Text("Stored on this iPhone").font(.headline); Text("Diary revisions, imported records, check-ins, profile answers, caffeine entries, morning notes, experiments, companion progress, sound blends and sound-event summaries stay in Lotus's application container. There is no analytics service, account, cloud sync or remote AI. Files use iOS Data Protection and are excluded from automatic backup. Protection allows access after the first unlock so an explicitly started recording can save summaries while the screen is locked.") }
            Surface { Text("You choose what leaves").font(.headline); Text("Sleep logs and JSON backups leave only when you use the export sheet. Exports are not encrypted: store them somewhere you trust. JSON backups include notes, profile answers, caffeine logs, morning notes, experiments, companion progress, blend settings, revisions and audio metadata, but no microphone recordings or imported sound files. Optional retained recordings can be shared individually and expire on the next app launch after the retention period.") }
            Surface { Text("Permissions on your terms").font(.headline); Text("Health access is read-only. Removing Health permission does not automatically erase records already imported. Microphone and motion permission can be changed in iPhone Settings. Deleting Lotus data does not delete source data in Apple Health or files you exported elsewhere.") }
        }.navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
    }
}
struct CapabilitiesView:View {
    var body:some View {
        LumaPage {
            SectionTitle(title:"Designed for iOS 17 and later")
            Text("Primary target: iPhone 14 Pro Max on iOS 27.2. Compatibility is expressed in the source and deployment target; a Mac build and real-device verification are still required.")
            ForEach([
                ["Diary & bedtime","No permission or wearable. Saved timestamps survive relaunch. Timer measures time in bed until you review it."],
                ["Apple Health","Available in the optional Health-enabled build. Foreground incremental import handles additions and deletions. Data may be delayed; empty results cannot distinguish no data from refused reading."],
                ["Motion review","Requires Motion & Fitness. Queries existing activity history; it does not run overnight sensors. A quiet phone is not evidence that you were asleep."],
                ["Sound events","Requires microphone permission and an explicitly started session. Audio background mode supports screen locking, but calls, route changes and termination can interrupt it. Events are level thresholds, not snore or apnea classifications."],
                ["Wake alarms","AlarmKit on iOS 26+. On older versions, use Apple's Clock app. Notifications can be silenced by Focus or system settings and are never described as alarm equivalents."],
                ["Not offered","No mattress sensing, smart light-sleep wake, apnea diagnosis, global unlock history or invented stages. Apple Health XML import is not implemented; CSV/JSON are available."]
            ],id:\.first) { item in Surface { Text(item[0]).font(.headline); Text(item[1]).foregroundStyle(.secondary) } }
        }.navigationTitle("Compatibility").navigationBarTitleDisplayMode(.inline)
    }
}
