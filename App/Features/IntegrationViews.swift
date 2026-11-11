import SwiftUI
import AVKit
struct HealthSourceView:View {
    @EnvironmentObject private var store:AppStore
    var sources:[String] { var result=store.data.preferences.sourcePriority; for source in Set(store.data.effectiveRecords.map(\.sourceID)).sorted() where !result.contains(source) { result.append(source) }; return result }
    var body:some View {
        List {
            Section("Apple Health") {
                Text(store.health.explanation)
                if store.busy { ProgressView("Reading Health changes…") }
                Button("Connect & read sleep") { Task{await store.syncHealth(requestAccess:true)} }.disabled(store.busy)
                Button("Check for changes") { Task{await store.syncHealth()} }.disabled(store.busy)
                if let date=store.data.lastHealthSync { Text("Last query completed: \(date.formatted(date:.abbreviated,time:.shortened))").font(.caption) }
                Text("No readable records can mean no data, delayed syncing, limited history or read access being off. Lotus cannot distinguish these. Check Health → Browse → Sleep → Data Sources & Access.").font(.footnote).foregroundStyle(.secondary)
                Text("Third-party devices must write sleep to Apple Health through their own app. Stage detail appears only when that source supplies it. There is no direct Oura, Garmin, Fitbit or other vendor login.").font(.footnote)
            }
            Section {
                ForEach(sources,id:\.self) { source in
                    VStack(alignment:.leading,spacing:4) { Text(source == "correction" ? "Your corrections (always first)" : source == "diary" ? "Your diary" : store.data.effectiveRecords.first(where:{$0.sourceID == source})?.sourceName ?? source); Text(source).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                }.onMove { offsets,destination in var order=sources; order.move(fromOffsets:offsets,toOffset:destination); store.updatePreferences{$0.sourcePriority=order} }
            } header: { Text("Source priority · drag to reorder") } footer: { Text("Corrections always win. Within a source, awake overrides asleep and explicit stages override unspecified sleep. Remaining conflicts use a stable source and record order. In-bed evidence is kept separately.") }
        }.navigationTitle("Sleep sources").toolbar{EditButton()}
    }
}
struct MotionView:View {
    @EnvironmentObject private var store:AppStore
    @State private var suggestions:[MotionSuggestion]=[]
    @State private var selected:MotionSuggestion?
    @State private var busy=false
    @State private var message:String?
    var body:some View {
        LumaPage {
            SectionTitle(title:"A quiet phone is a clue.",subtitle:"It doesn't prove you were asleep.")
            Text("Lotus can query recent motion activity and offer a stationary-phone window for you to review. It reads historical activity; it does not access screen time, unlock history or continuous background accelerometer data.")
            PrimaryButton(title:"Review the last 24 hours",symbol:"figure.walk") {
                guard !store.isDemo else{message="Motion history is disabled in demo mode.";return}
                busy=true; Task { defer{busy=false}; do { suggestions=try await store.motion.suggest(from:store.now.addingTimeInterval(-86400),to:store.now); message=suggestions.isEmpty ? "No suitable stationary windows were returned. You can still add a diary entry." : "Review a window below before using it." }catch{message=error.localizedDescription} }
            }.disabled(busy)
            if busy { ProgressView("Reading activity history…") }
            if let message { Text(message).foregroundStyle(.secondary) }
            ForEach(suggestions) { s in Button { selected=s } label: { Surface { Text("Possible rest window").font(.headline); Text("\(s.start.formatted(date:.abbreviated,time:.shortened)) → \(s.end.formatted(date:.abbreviated,time:.shortened))"); Text("\(Luma.duration(s.end.timeIntervalSince(s.start))) · needs your confirmation").font(.caption) } }.buttonStyle(.plain) }
            Text("Activity history covers at most seven days and may be delayed. Lotus does not extend the final activity sample to the present. No mattress mode is included because it cannot be validated here under iOS background constraints.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Motion review").sheet(item:$selected){DiaryEditor(version:$0.version)}
    }
}
struct AudioView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback=SoundPlayback()
    var body:some View {
        LumaPage {
            SectionTitle(title:"Hear what happened.",subtitle:"Real microphone levels. Private replay. Your interpretation.")
            Text("The first five seconds calibrate the room. Sound events adapt to background levels, but a fan, another person or traffic can still trigger them. They do not automatically change your sleep log.").font(.subheadline).foregroundStyle(.secondary)
            NightSoundPanel(monitor:store.audio,beforeStart:{playback.stop()})
            Stepper("Keep saved audio for \(store.data.preferences.audioRetentionDays) days",value:Binding(get:{store.data.preferences.audioRetentionDays},set:{value in playback.stop(); store.updatePreferences{$0.audioRetentionDays=value}; store.audio.prune()}),in:1...30)
            Text("Keep the microphone uncovered on a stable bedside surface. Calls, route changes or force-quitting the app can interrupt monitoring. Sessions stop at 12 hours, 400 MB, low storage or 6,000 events. Audio stays on your iPhone unless you export it.").font(.footnote).foregroundStyle(.secondary)
            if playback.playingID != nil { Button("Stop playback",systemImage:"stop.circle") { playback.stop() } }
            SectionTitle(title:"Your recordings")
            if store.data.audioSessions.isEmpty { EmptyPanel(symbol:"waveform",title:"Your first sound journal",text:"Enable replay, start monitoring and make a short sound after calibration. Stop monitoring to hear the saved event.") }
            ForEach(store.data.audioSessions.reversed()) { item in SoundSessionCard(session:item,playback:playback) }
        }.navigationTitle("Sound journal")
            .onDisappear { playback.stop() }
            .onChange(of:scenePhase) { _,phase in if phase != .active { playback.stop() } }
    }
}
struct AudioControls:View {
    @EnvironmentObject private var store:AppStore
    @ObservedObject var monitor:AudioMonitor
    var beforeStart:()->Void = {}
    @State private var busy=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(monitor.status).font(.subheadline)
            if busy || monitor.isStarting { ProgressView("Starting…") }
            if monitor.isRunning { PrimaryButton(title:"Stop sound monitoring",symbol:"stop.circle") { monitor.stop() } }
            else { PrimaryButton(title:"Start sound monitoring",symbol:"mic") { beforeStart();busy=true;Task{defer{busy=false};do{try await monitor.start(retain:store.data.preferences.retainAudio)}catch{store.message=error.localizedDescription}} }.disabled(busy || monitor.isStarting) }
        }
    }
}
