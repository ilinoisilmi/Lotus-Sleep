import SwiftUI
struct SleepExperimentsView:View {
    @EnvironmentObject private var store:AppStore
    @State private var creating=false
    var body:some View {
        LumaPage {
            SectionTitle(title:"Find what suits your nights.",subtitle:"Compare one small change over fourteen nights.")
            Text("Keep your usual opportunity for enough sleep. Compare comfortable routines, such as quiet versus a soft sound. Record what you actually tried; skip a night if neither option fits.").font(.subheadline).foregroundStyle(.secondary)
            Button("Start an experiment",systemImage:"plus") { creating=true }.buttonStyle(.borderedProminent).disabled(store.data.experiments.contains{!$0.archived})
            if store.data.experiments.contains(where:{!$0.archived}) { Text("Finish or archive your active experiment before starting another.").font(.caption).foregroundStyle(.secondary) }
            if store.data.experiments.isEmpty { EmptyPanel(symbol:"chart.bar.xaxis",title:"One change. A clearer comparison.",text:"Each morning, record the option you used and how rested you feel. Your sleep diary adds context when available.") }
            ForEach(store.data.experiments.reversed()) { experiment in
                NavigationLink { ExperimentDetailView(id:experiment.id) } label: {
                    Surface {
                        HStack { Text(experiment.title).font(.headline);Spacer();Image(systemName:"chevron.right") }
                        Text("A · \(experiment.optionA)\nB · \(experiment.optionB)").font(.subheadline).foregroundStyle(.secondary)
                        Text("\(experiment.nights.count) of 14 mornings logged · \(experiment.archived ? "Archived" : "Active")").font(.caption)
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Sleep experiments")
            .sheet(isPresented:$creating) { NewExperimentView() }
    }
}
private struct NewExperimentView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title="Quiet vs pink noise"
    @State private var a="Quiet room"
    @State private var b="Pink noise at low volume"
    @State private var firstDay=Date()
    @State private var error:String?
    private var calendar:Calendar { SleepCalendar.calendar(zoneID:store.data.preferences.reportingTimeZoneID) }
    private var tomorrow:Date { calendar.date(byAdding:.day,value:1,to:calendar.startOfDay(for:store.now))! }
    var body:some View {
        NavigationStack {
            Form {
                Section("Change one thing") { TextField("Experiment name",text:$title);TextField("Option A",text:$a);TextField("Option B",text:$b) }
                Section("Fourteen mornings") {
                    DatePicker("First morning",selection:$firstDay,in:tomorrow...,displayedComponents:.date).environment(\.timeZone,calendar.timeZone)
                    Text("The plan alternates in a balanced A/B order, seven nights each. You confirm the option actually used. The first night is the evening before this morning date.").font(.caption).foregroundStyle(.secondary)
                    Text("Dates stay in \(calendar.timeZone.identifier), even if your reporting timezone later changes.").font(.caption)
                }
                Text("Results are descriptive, not a medical test. Stress, illness, work and chance can affect a comparison. Do not shorten sleep or change medication to run an experiment.").font(.footnote).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("New experiment").onAppear{firstDay=tomorrow}
                .toolbar {
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Start") {
                        do {
                            let experiment=SleepExperiment(title:title.trimmingCharacters(in:.whitespacesAndNewlines),optionA:a.trimmingCharacters(in:.whitespacesAndNewlines),optionB:b.trimmingCharacters(in:.whitespacesAndNewlines),startDay:firstDay,timeZoneID:calendar.timeZone.identifier,boundaryHour:store.data.preferences.boundaryHour)
                            try experiment.validate();try store.transact{$0.experiments.append(experiment)};dismiss()
                        } catch { self.error=error.localizedDescription }
                    }}
                }
        }
    }
}
private struct ExperimentDaySelection:Identifiable { let id:Int }
struct ExperimentDetailView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let id:UUID
    @State private var selection:ExperimentDaySelection?
    @State private var confirmDelete=false
    private var experiment:SleepExperiment? { store.data.experiments.first{$0.id == id} }
    var body:some View {
        LumaPage {
            if let experiment {
                let result=ExperimentComparison.calculate(experiment,snapshot:store.data,now:store.now)
                SectionTitle(title:experiment.title,subtitle:experiment.archived ? "Archived comparison" : "Your fourteen-night comparison")
                Surface {
                    Text("A · \(experiment.optionA)\nB · \(experiment.optionB)").font(.headline)
                    Text("\(result.a.count) A mornings · \(result.b.count) B mornings · \(result.skipped) skipped").font(.subheadline)
                    if result.ready {
                        group("A",result.a);group("B",result.b)
                        if let a=result.a.meanRested,let b=result.b.meanRested { Text("B minus A: \((b-a).formatted(.number.precision(.fractionLength(1)))) points on your 1–5 rested scale.").font(.subheadline) }
                        Text("This describes your reports. It does not establish cause or predict future nights. Small differences may be noise.").font(.caption).foregroundStyle(.secondary)
                    } else { Text("Log at least three rated mornings for each option before showing averages. Skipped and missing nights are excluded.").font(.subheadline).foregroundStyle(.secondary) }
                }
                SectionTitle(title:"Morning log")
                ForEach(0..<14,id:\.self) { index in
                    let report=experiment.nights.first{$0.dayIndex == index}
                    Button { selection=ExperimentDaySelection(id:index) } label: {
                        HStack {
                            VStack(alignment:.leading,spacing:5) {
                                Text(Luma.day(experiment.day(index),zoneID:experiment.timeZoneID)).font(.headline)
                                Text(report.map{ $0.condition == .skipped ? "Skipped" : "Used \($0.condition.rawValue) · rested \($0.rested ?? 0)/5" } ?? "Planned \(experiment.planned(index).rawValue) · not logged").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer();Image(systemName:report == nil ? "circle" : "checkmark.circle")
                        }.padding(.vertical,9)
                    }.buttonStyle(.plain).disabled(index > experiment.availableIndex(at:store.now) || experiment.archived)
                }
                Text("Sleep averages use the experiment’s original timezone and sleep-day boundary, include naps, and exclude days with no confirmed sleep. Diary corrections can change those averages; your morning ratings stay as entered.").font(.caption).foregroundStyle(.secondary)
                Button(experiment.archived ? "Reopen experiment" : "Finish & archive experiment") {
                    store.perform { try store.transact { data in if let i=data.experiments.firstIndex(where:{$0.id == id}) { data.experiments[i].archived.toggle() } } }
                }.disabled(experiment.archived && store.data.experiments.contains{!$0.archived && $0.id != id})
                Button("Delete experiment",role:.destructive) { confirmDelete=true }
            }
        }.navigationTitle("Experiment").navigationBarTitleDisplayMode(.inline)
            .sheet(item:$selection) { day in if let experiment { ExperimentMorningEditor(experiment:experiment,index:day.id) } }
            .alert("Delete this experiment?",isPresented:$confirmDelete) {
                Button("Delete",role:.destructive){store.perform{try store.transact{$0.experiments.removeAll{$0.id == id}}};dismiss()}
                Button("Cancel",role:.cancel){}
            } message:{Text("Its ratings and notes will be removed. Your sleep diary stays unchanged.")}
    }
    private func group(_ title:String,_ value:ExperimentGroupSummary)->some View {
        VStack(alignment:.leading,spacing:4) {
            Text("\(title): \(value.meanRested?.formatted(.number.precision(.fractionLength(1))) ?? "—") / 5 rested · \(value.count) ratings").font(.headline)
            Text("Sleep-day average: \(value.meanSleepHours.map{Luma.duration($0*3600)} ?? "unknown") · \(value.sleepCount) days with sleep data").font(.caption).foregroundStyle(.secondary)
        }
    }
}
private struct ExperimentMorningEditor:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    let experiment:SleepExperiment
    let index:Int
    @State private var condition=ExperimentCondition.a
    @State private var rating=0
    @State private var notes=""
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Text(Luma.day(experiment.day(index),zoneID:experiment.timeZoneID)).font(.headline)
                Picker("What did you actually try?",selection:$condition) { Text("A · \(experiment.optionA)").tag(ExperimentCondition.a);Text("B · \(experiment.optionB)").tag(ExperimentCondition.b);Text("Neither / skipped").tag(ExperimentCondition.skipped) }
                if condition != .skipped { Picker("How rested did you feel?",selection:$rating) { Text("Choose a rating").tag(0);ForEach(1...5,id:\.self){Text("\($0) / 5").tag($0)} } }
                TextField("Context: illness, stress, unusual schedule…",text:$notes,axis:.vertical)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Morning report").onAppear {
                let entry=experiment.nights.first{$0.dayIndex == index};condition=entry?.condition ?? experiment.planned(index);rating=entry?.rested ?? 0;notes=entry?.notes ?? ""
            }.toolbar {
                ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                ToolbarItem(placement:.confirmationAction){Button("Save") {
                    do {
                        let report=ExperimentNight(dayIndex:index,condition:condition,rested:condition == .skipped ? nil : rating,notes:notes)
                        try store.transact { data in guard let i=data.experiments.firstIndex(where:{$0.id == experiment.id}) else { throw LumaError.invalid("Experiment no longer exists.") };try data.experiments[i].log(report,at:store.now) };dismiss()
                    } catch { self.error=error.localizedDescription }
                }}
            }
        }
    }
}
