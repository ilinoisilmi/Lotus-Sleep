import SwiftUI
struct DiaryEditor: View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let entryID:UUID?
    let replacing:[String]
    @State private var draft:DiaryVersion
    @State private var estimatesSleep:Bool
    @State private var sleepStart:Date
    @State private var error:String?
    @State private var tags:String
    init(version:DiaryVersion? = nil, entryID:UUID? = nil, replacing:[String] = [], kind:SleepKind = .main) {
        let now=Date()
        var v=version ?? DiaryVersion(bedtime:now.addingTimeInterval(-9*3600),sleepStart:now.addingTimeInterval(-8.5*3600),wake:now,outOfBed:now,timeZoneID:TimeZone.current.identifier)
        if version == nil { v.kind=kind; if kind == .nap { v.bedtime=now.addingTimeInterval(-1800); v.sleepStart=v.bedtime } }
        self.entryID=entryID; self.replacing=replacing
        _draft=State(initialValue:v); _estimatesSleep=State(initialValue:v.sleepStart != nil)
        _sleepStart=State(initialValue:v.sleepStart ?? v.bedtime.addingTimeInterval(min(1200,max(0,v.wake.timeIntervalSince(v.bedtime)/2)))); _tags=State(initialValue:v.tags.joined(separator:", "))
    }
    var body:some View {
        NavigationStack {
            Form {
                Section { Text("Your estimate is useful. You can correct it later; the original version is kept.").foregroundStyle(.secondary) }
                if draft.includesInBedEvidence == false {
                    Section { Text("This quick log did not record time in bed. Check Went to bed and Got out of bed below before saving a detailed diary.").font(.subheadline).foregroundStyle(.secondary) }
                }
                Section("Sleep window") {
                    Picker("Type",selection:$draft.kind) { Text("Main sleep / split sleep").tag(SleepKind.main); Text("Nap").tag(SleepKind.nap) }
                    DatePicker("Went to bed",selection:$draft.bedtime)
                    Toggle("Estimate time asleep",isOn:$estimatesSleep)
                    if estimatesSleep { DatePicker("Fell asleep",selection:$sleepStart) }
                    DatePicker("Final wake",selection:$draft.wake)
                    DatePicker("Got out of bed",selection:$draft.outOfBed)
                    TextField("IANA timezone",text:$draft.timeZoneID).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Dates include the day so midnight crossings and split sleep are explicit. Dates below are displayed in the timezone above when valid.").font(.caption).foregroundStyle(.secondary)
                }
                let loggedWakeups=store.data.disturbances.filter{$0.start < draft.outOfBed && ($0.end ?? draft.outOfBed) > draft.bedtime}
                if !loggedWakeups.isEmpty {
                    Section("Your nighttime notes") {
                        ForEach(loggedWakeups) { entry in
                            VStack(alignment:.leading,spacing:4) {
                                Text(entry.reason.title).font(.subheadline.weight(.medium))
                                Text(entry.start.formatted(date:.omitted,time:.shortened)).font(.caption)
                                if !entry.notes.isEmpty { Text(entry.notes).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        Text("Enable Estimate time asleep, check your sleep window, then use Include logged wake-ups below to subtract these intervals. An open log needs an end time first.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if estimatesSleep {
                    Section("Awakenings") {
                        ForEach($draft.awakenings) { $awake in
                            VStack(alignment:.leading) { DatePicker("Awake from",selection:$awake.start); DatePicker("Back asleep",selection:$awake.end) }
                        }.onDelete { draft.awakenings.remove(atOffsets:$0) }
                        Button("Add awakening",systemImage:"plus") { let start=sleepStart.addingTimeInterval(max(0,draft.wake.timeIntervalSince(sleepStart)/2)); draft.awakenings.append(AwakeInterval(start:start,end:min(draft.wake,start.addingTimeInterval(600)))) }
                        let logged=DisturbanceActions.intervals(store.data.disturbances,sleepStart:sleepStart,wake:draft.wake)
                        if !logged.isEmpty {
                            Button("Include \(logged.count) logged wake-up interval\(logged.count == 1 ? "" : "s")",systemImage:"moon.zzz") {
                                let combined=draft.awakenings+logged
                                guard combined.allSatisfy({$0.start < $0.end}) else { error="Fix the existing awakening times before adding logged wake-ups."; return }
                                draft.awakenings=SleepReconciler.union(combined.map{DateInterval(start:$0.start,end:$0.end)}).map{AwakeInterval(start:$0.start,end:$0.end)}
                            }
                            Text("These end when you tapped return to rest. Adjust the times to your best estimate of falling asleep again.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("How it felt") {
                    Picker("Quality",selection:Binding(get:{draft.qualityRating ?? 0},set:{draft.qualityRating=$0 == 0 ? nil : $0})) { Text("Not rated").tag(0); ForEach(1...5,id:\.self) { Text("\($0) / 5").tag($0) } }
                    TextField("Tags, separated by commas",text:$tags)
                    Text("Examples: Exercise, Late caffeine, Stress, Illness, Late meal").font(.caption).foregroundStyle(.secondary)
                    TextField("Notes",text:$draft.notes,axis:.vertical).lineLimit(3...6)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .environment(\.timeZone,TimeZone(identifier:draft.timeZoneID) ?? .current)
            .navigationTitle(entryID == nil && replacing.isEmpty ? "Sleep diary" : "Review your night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement:.confirmationAction) { Button("Save") { save() }.fontWeight(.semibold) }
            }
        }
    }
    private func save() {
        draft.sleepStart=estimatesSleep ? sleepStart : nil
        draft.includesInBedEvidence=true
        if !estimatesSleep { draft.awakenings=[] }
        draft.tags=Array(Set(tags.split(separator:",").map{$0.trimmingCharacters(in:.whitespaces)}.filter{!$0.isEmpty})).sorted()
        draft.id=UUID(); draft.savedAt=store.now
        do { try store.saveDiary(draft,editing:entryID,replacing:replacing); dismiss() } catch { self.error=error.localizedDescription }
    }
}
