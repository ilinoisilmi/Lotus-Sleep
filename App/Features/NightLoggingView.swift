import SwiftUI

extension NightRating {
    var tint:Color {
        switch self {
        case .unlogged:return .secondary
        case .good:return Color(uiColor:.systemGreen)
        case .mixed:return Luma.warm
        case .attention:return Color(uiColor:.systemRed)
        }
    }
}

struct DisturbanceView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var past=false
    private var active:SleepDisturbance? { store.data.disturbances.first{$0.end == nil} }
    var body:some View {
        NavigationStack {
            LumaPage {
                SectionTitle(title:"Awake in the night?",subtitle:"A quiet place to log it and settle again.")
                if let entry=active {
                    Surface {
                        Label("Wake-up saved",systemImage:"checkmark.circle").foregroundStyle(Luma.lavender)
                        Text("You can close this screen or lock your phone. Your bedtime session keeps running.").font(.subheadline).foregroundStyle(.secondary)
                        Picker("What woke you?",selection:Binding(get:{active?.reason ?? .unsure},set:{reason in update(entry.id){$0.reason=reason}})) {
                            ForEach(DisturbanceReason.allCases,id:\.self) { Text($0.title).tag($0) }
                        }
                        TextField("Anything on your mind? (optional)",text:Binding(get:{active?.notes ?? ""},set:{notes in update(entry.id){$0.notes=String(notes.prefix(4000))}}),axis:.vertical).lineLimit(2...4)
                    }
                    guidance(entry.reason)
                    PrimaryButton(title:"Try sleeping again",symbol:"moon") {
                        store.perform { try store.transact { try DisturbanceActions.finish(snapshot:&$0,id:entry.id,at:store.now) }; dismiss() }
                    }
                    Text("This marks your return to rest, not the exact moment you fell asleep. Review the interval in the morning.").font(.caption).foregroundStyle(.secondary)
                    Button("Discard this wake-up",role:.destructive) { store.perform { try store.transact { $0.disturbances.removeAll{$0.id == entry.id} }; dismiss() } }
                } else {
                    PrimaryButton(title:"I'm awake now",symbol:"moon.zzz") { store.perform { try store.transact { DisturbanceActions.start(snapshot:&$0,at:store.now) } } }
                    guidance(.unsure)
                }
                NavigationLink { MorningInboxView() } label: { Label("Leave a note for the morning",systemImage:"tray") }
                Button("Log an earlier wake-up",systemImage:"clock.arrow.circlepath") { past=true }
                if !store.data.disturbances.isEmpty {
                    SectionTitle(title:"Recent wake-ups")
                    ForEach(Array(store.data.disturbances.sorted{$0.start > $1.start}.prefix(10))) { entry in
                        Surface {
                            Text(entry.reason.title).font(.headline)
                            Text(entry.start.formatted(date:.abbreviated,time:.shortened)).font(.subheadline)
                            Text(entry.end.map { "Returned to rest: \($0.formatted(date:.omitted,time:.shortened))" } ?? "Still open — finish or discard above").font(.caption).foregroundStyle(.secondary)
                            if !entry.notes.isEmpty { Text(entry.notes).font(.subheadline) }
                            if entry.end != nil { Button("Delete log",role:.destructive) { store.perform { try store.transact { $0.disturbances.removeAll{$0.id == entry.id} } } } }
                        }
                    }
                }
            }.navigationTitle("Nighttime help").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Close") { dismiss() } } }
                .sheet(isPresented:$past) { PastDisturbanceView() }
        }.preferredColorScheme(.dark)
    }
    private func update(_ id:UUID,change:(inout SleepDisturbance)->Void) {
        store.perform { try store.transact { s in if let i=s.disturbances.firstIndex(where:{$0.id == id}) { change(&s.disturbances[i]) } } }
    }
    private func guidance(_ reason:DisturbanceReason)->some View {
        Surface {
            Text("A gentle reset").font(.headline)
            Text(reason.guidance)
            Text("If you feel wide awake and frustrated, take a quiet break out of bed in dim light, then return when sleepy. Avoid repeatedly checking the clock; put this screen away once you have logged your wake-up.").font(.subheadline).foregroundStyle(.secondary)
            Text("General guidance, not a diagnosis. If this keeps happening or affects your daytime functioning, talk with a healthcare professional.").font(.caption).foregroundStyle(.secondary)
            Link("Why these suggestions? · NIH sleep guidance",destination:URL(string:"https://www.nhlbi.nih.gov/health/insomnia/treatment")!).font(.caption)
        }
    }
}

struct PastDisturbanceView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var start=Date().addingTimeInterval(-1800)
    @State private var end=Date()
    @State private var reason=DisturbanceReason.unsure
    @State private var notes=""
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Section("What you remember") {
                    DatePicker("Woke up",selection:$start,in:...Date())
                    DatePicker("Returned to rest",selection:$end,in:...Date())
                    Picker("Reason",selection:$reason) { ForEach(DisturbanceReason.allCases,id:\.self){Text($0.title).tag($0)} }
                    TextField("Notes",text:$notes,axis:.vertical)
                    Text("This is your estimate. Include it in a sleep diary to adjust recorded time asleep.").font(.caption)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Earlier wake-up").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){
                        do {
                            var entry=SleepDisturbance(start:start,end:end); entry.reason=reason; entry.notes=notes
                            try entry.validate(); try store.transact{$0.disturbances.append(entry)}; dismiss()
                        } catch { self.error=error.localizedDescription }
                    }}
                }
        }
    }
}

struct QuickSleepView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var hours=8.0
    @State private var wake=Date()
    @State private var kind=SleepKind.main
    @State private var quality=0
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Section("A quick estimate") {
                    Picker("Type",selection:$kind) { Text("Night / split sleep").tag(SleepKind.main); Text("Nap").tag(SleepKind.nap) }
                    DatePicker("Woke up",selection:$wake,in:...Date())
                    Stepper("\(Luma.duration(hours*3600)) asleep",value:$hours,in:0.25...16,step:0.25)
                    Picker("Quality",selection:$quality) { Text("Not rated").tag(0); ForEach(1...5,id:\.self){Text("\($0) / 5").tag($0)} }
                    Text("Use this for roughly continuous sleep. It places your estimated sleep immediately before your wake time. For long awakenings or separate sleep blocks, use the detailed diary.").font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Quick sleep log").navigationBarTitleDisplayMode(.inline)
                .onChange(of:kind) { _,value in hours=value == .nap ? 0.5 : 8 }
                .toolbar {
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){
                        let start=wake.addingTimeInterval(-hours*3600)
                        var v=DiaryVersion(bedtime:start,sleepStart:start,wake:wake,outOfBed:wake,timeZoneID:TimeZone.current.identifier)
                        v.kind=kind; v.qualityRating=quality == 0 ? nil : quality
                        v.includesInBedEvidence=false
                        v.notes="Quick duration estimate; actual time in bed was not recorded."
                        do { try store.saveDiary(v); dismiss() } catch { self.error=error.localizedDescription }
                    }}
                }
        }
    }
}
