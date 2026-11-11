import SwiftUI
struct TrackView: View {
    @EnvironmentObject private var store:AppStore
    @State private var manual=false
    @State private var nap=false
    @State private var bedside=false
    @State private var review:DiaryEntry?
    @State private var wakeHelp=false
    @State private var quick=false
    var body:some View {
        LumaPage {
            SectionTitle(title:"Rest begins here.",subtitle:"Choose the evidence that works for you.")
            if let active=store.data.activeSession {
                Surface {
                    Eyebrow(text:active.kind == .nap ? "Nap · time in bed" : "Bedtime is running")
                    TimelineView(.periodic(from:.now,by:60)) { context in Text(Luma.duration(context.date.timeIntervalSince(active.startedAt))).font(.system(.largeTitle,design:.rounded,weight:.medium)) }
                    Text("Started \(active.startedAt.formatted(date:.abbreviated,time:.shortened)). This is time in bed, not measured sleep.").font(.subheadline).foregroundStyle(.secondary)
                    PrimaryButton(title:"End night & review",symbol:"sun.max") { store.endBedtime() }
                    Button("I woke up · log & get help",systemImage:"moon.zzz") { logWake() }
                    Button("Open bedside display") { bedside=true }
                    if store.now.timeIntervalSince(active.startedAt)>48*3600 { Button("Discard stale timer",role:.destructive) { store.perform { try store.transact { $0.activeSession=nil } } } }
                }
            } else {
                preferredAction
                if store.data.preferences.preferredMethod != .bedtime { Button("Start a bedtime session",systemImage:"moon.zzz") { store.startBedtime(); bedside=store.data.activeSession != nil } }
            }
            HStack { Button("Add sleep",systemImage:"square.and.pencil") { manual=true }; Spacer(); Button("Log a nap",systemImage:"sun.haze") { nap=true } }.buttonStyle(.bordered).controlSize(.large)
            HStack { Button("Quick duration",systemImage:"clock.badge.checkmark") { quick=true }; Spacer(); Button("Nighttime help",systemImage:"moon.zzz") { wakeHelp=true } }.buttonStyle(.bordered)
            if store.data.disturbances.contains(where:{$0.end == nil}) {
                Button("Finish your open wake-up log",systemImage:"moon") { wakeHelp=true }
            }
            ForEach(store.data.diaries.filter{!$0.isDeleted && $0.current.sleepStart == nil}) { entry in
                Button { review=entry } label: { Surface { Label("Morning review",systemImage:"checkmark.circle").font(.headline); Text("\(entry.current.bedtime.formatted(date:.abbreviated,time:.shortened)) → \(entry.current.outOfBed.formatted(date:.abbreviated,time:.shortened))").font(.subheadline); Text("Confirm your estimated sleep window.").foregroundStyle(.secondary) } }.buttonStyle(.plain)
            }
            SectionTitle(title:"Ways to track")
            NavigationLink { RelaxationView() } label: { Label("Relaxing sounds & your MP3s",systemImage:"speaker.wave.2") }
            VStack(spacing:0) {
                method("Manual diary","Your estimate, notes and habits","square.and.pencil") { manual=true }
                Divider().padding(.vertical,10)
                NavigationLink { HealthSourceView() } label: { methodLabel("Apple Health","Apple Watch or a compatible source","heart.text.square") }.buttonStyle(.plain)
                Divider().padding(.vertical,10)
                NavigationLink { MotionView() } label: { methodLabel("Motion-assisted review","Suggest a quiet-phone window","figure.walk") }.buttonStyle(.plain)
                Divider().padding(.vertical,10)
                NavigationLink { AudioView() } label: { methodLabel("Overnight sound events","Optional, processed on your iPhone","waveform") }.buttonStyle(.plain)
                Divider().padding(.vertical,10)
                NavigationLink { ImportView() } label: { methodLabel("Import a sleep log","CSV or JSON with a preview","square.and.arrow.down") }.buttonStyle(.plain)
            }
            Text("No wearable required. Lotus never infers sleep stages from a stationary phone or sound levels.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Track").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented:$manual) { DiaryEditor() }
        .sheet(isPresented:$nap) { DiaryEditor(kind:.nap) }
        .sheet(item:$review) { DiaryEditor(version:$0.current,entryID:$0.id) }
        .sheet(isPresented:$wakeHelp) { DisturbanceView() }
        .sheet(isPresented:$quick) { QuickSleepView() }
        .fullScreenCover(isPresented:$bedside,onDismiss:openPendingReview) { BedsideView() }
        .onChange(of:store.pendingReviewID) { _,_ in if !bedside { openPendingReview() } }
        .onAppear { if !bedside { openPendingReview() } }
    }
    private func logWake() {
        store.perform { try store.transact { DisturbanceActions.start(snapshot:&$0,at:store.now) }; wakeHelp=true }
    }
    private func openPendingReview() {
        if let id=store.pendingReviewID {
            review=store.data.diaries.first{$0.id == id}
            store.pendingReviewID=nil
        }
    }
    @ViewBuilder private var preferredAction:some View {
        switch store.data.preferences.preferredMethod {
        case .bedtime: PrimaryButton(title:"Start bedtime",symbol:"moon.zzz") { store.startBedtime(); bedside=store.data.activeSession != nil }
        case .diary: PrimaryButton(title:"Add a diary entry",symbol:"square.and.pencil") { manual=true }
        case .health: NavigationLink { HealthSourceView() } label: { Label("Open Apple Health tracking",systemImage:"heart.text.square").frame(maxWidth:.infinity).padding(12) }.buttonStyle(.borderedProminent).tint(.indigo)
        case .motion: NavigationLink { MotionView() } label: { Label("Review motion history",systemImage:"figure.walk").frame(maxWidth:.infinity).padding(12) }.buttonStyle(.borderedProminent).tint(.indigo)
        case .file: NavigationLink { ImportView() } label: { Label("Import a sleep log",systemImage:"doc.badge.plus").frame(maxWidth:.infinity).padding(12) }.buttonStyle(.borderedProminent).tint(.indigo)
        }
    }
    private func method(_ title:String,_ subtitle:String,_ icon:String,action:@escaping()->Void)->some View { Button(action:action) { methodLabel(title,subtitle,icon) }.buttonStyle(.plain) }
    private func methodLabel(_ title:String,_ subtitle:String,_ icon:String)->some View {
        HStack(spacing:16) { Image(systemName:icon).font(.title2).foregroundStyle(Luma.lavender).frame(width:30); VStack(alignment:.leading,spacing:5) { Text(title).font(.headline); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary) }.padding(.vertical,10).frame(minHeight:50)
    }
}
struct BedsideView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var wakeHelp=false
    @State private var sounds=false
    var body:some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView { VStack(spacing:24) {
                HStack { Spacer(); Button("Close") { dismiss() }.padding() }
                Image(systemName:"moon.stars").font(.system(size:48,weight:.ultraLight)).foregroundStyle(Color(red:0.62,green:0.58,blue:0.79)).accessibilityHidden(true)
                if let active=store.data.activeSession {
                    Text("Nothing to do.\nTime to rest.").font(.system(.largeTitle,design:.rounded,weight:.light)).multilineTextAlignment(.center)
                    TimelineView(.periodic(from:.now,by:60)) { context in Text("\(Luma.duration(context.date.timeIntervalSince(active.startedAt))) in bed").font(.headline.monospacedDigit()).foregroundStyle(.gray) }
                    Text("You can lock your iPhone. Your start time is saved.").font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center)
                }
                NightSoundPanel(monitor:store.audio)
                Button("Sleep sounds & MP3s",systemImage:"speaker.wave.2") { sounds=true }
                Button { store.perform { try store.transact { DisturbanceActions.start(snapshot:&$0,at:store.now) }; wakeHelp=true } } label: {
                    Label("I woke up · help me settle",systemImage:"moon.zzz").font(.headline).frame(maxWidth:.infinity).padding(.vertical,16)
                }.buttonStyle(.bordered)
                PrimaryButton(title:"End night & review",symbol:"sun.max") { store.endBedtime(); if store.data.activeSession == nil { dismiss() } }
            }.padding(.horizontal,24).padding(.bottom,30).foregroundStyle(.white) }
        }.preferredColorScheme(.dark)
            .sheet(isPresented:$wakeHelp) { DisturbanceView() }
            .sheet(isPresented:$sounds) { NavigationStack { RelaxationView().toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { sounds=false } } } } }
    }
}
