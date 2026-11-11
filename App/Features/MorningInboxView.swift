import SwiftUI

struct MorningInboxView:View {
    @EnvironmentObject private var store:AppStore
    @State private var editing:MorningTask?
    @State private var deleting:MorningTask?
    @State private var completedLimit=20
    private var active:[MorningTask] { MorningInbox.active(store.data.morningTasks) }
    private var completed:[MorningTask] { store.data.morningTasks.filter{$0.completedAt != nil}.sorted{($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)} }
    var body:some View {
        TimelineView(.periodic(from:Date(),by:30)) { _ in
        List {
            Section {
                Text("Leave yourself the details you want to remember after waking: take the charger, bring the documents, make that call.").foregroundStyle(.secondary)
                Button("Leave a morning note",systemImage:"plus") { editing=MorningTask(text:"",createdAt:store.now,remindAt:store.plan.wake) }
            }
            Section("Ready to act on") {
                let due=active.filter{$0.isDue(at:store.now)}
                if due.isEmpty { Text("Nothing waiting right now.").foregroundStyle(.secondary) }
                ForEach(due) { row($0) }
            }
            Section("Coming up") {
                let upcoming=active.filter{!$0.isDue(at:store.now)}
                if upcoming.isEmpty { Text("No upcoming notes.").foregroundStyle(.secondary) }
                ForEach(upcoming) { row($0) }
            }
            if !completed.isEmpty {
                Section("Done") {
                    ForEach(Array(completed.prefix(completedLimit))) { row($0) }
                    if completed.count > completedLimit { Button("Show more completed notes") { completedLimit+=20 } }
                }
            }
            Section {
                Text("Notes stay on this iPhone and are included in your JSON backup. Reminder text is hidden on the lock screen unless you choose to show it. Reopening a completed note does not reschedule its reminder; edit it to choose a new time.").font(.caption).foregroundStyle(.secondary)
                NavigationLink("Notification settings") { NotificationsView() }
            }
        }
        }.navigationTitle("Morning inbox").disabled(store.morningTaskBusy)
            .sheet(item:$editing) { MorningTaskEditor(task:$0) }
            .alert("Delete this note?",isPresented:Binding(get:{deleting != nil},set:{if !$0 { deleting=nil }})) {
                Button("Delete",role:.destructive) { if let note=deleting { store.deleteMorningTask(note.id) };deleting=nil }
                Button("Cancel",role:.cancel) { deleting=nil }
            } message:{ Text("The note and its pending reminder will be removed.") }
    }
    private func row(_ note:MorningTask)->some View {
        HStack(alignment:.top,spacing:12) {
            Button { store.completeMorningTask(note.id,done:note.completedAt == nil) } label:{ Image(systemName:note.completedAt == nil ? "circle" : "checkmark.circle.fill").font(.title2).frame(minWidth:36,minHeight:44) }
                .buttonStyle(.borderless).accessibilityLabel(note.completedAt == nil ? "Mark done: \(note.text)" : "Reopen: \(note.text)")
            VStack(alignment:.leading,spacing:7) {
                Text(note.text).strikethrough(note.completedAt != nil).foregroundStyle(note.completedAt == nil ? .primary : .secondary)
                Text(note.remindAt.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                if note.notificationScheduled && note.remindAt > store.now { Label("Reminder scheduled",systemImage:"bell").font(.caption) }
                HStack { Button("Edit"){editing=note};Spacer();Button("Delete",role:.destructive){deleting=note} }.font(.caption).buttonStyle(.borderless)
            }.padding(.vertical,4)
        }
    }
}
private struct MorningTaskEditor:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft:MorningTask
    @State private var notify:Bool
    @State private var error:String?
    init(task:MorningTask) {
        _draft=State(initialValue:task)
        _notify=State(initialValue:task.notificationScheduled || task.text.isEmpty)
    }
    var body:some View {
        NavigationStack {
            Form {
                Section("Remember this") {
                    TextField("Take my charger before leaving",text:$draft.text,axis:.vertical).lineLimit(3...8).accessibilityIdentifier("morning.note")
                    Text("\(draft.text.count) / 1,000 characters").font(.caption).foregroundStyle(.secondary)
                    DatePicker("When to act",selection:$draft.remindAt)
                }
                if draft.completedAt == nil {
                    Section("Optional reminder") {
                        Toggle("Notify me at this time",isOn:$notify).disabled(store.isDemo)
                        if notify { Toggle("Show note text in the notification",isOn:$draft.showPreview) }
                        Text(store.isDemo ? "Demo notes stay in the demo. Notifications are disabled." : "With text hidden, the notification simply asks you to open your morning inbox. Choose a future time to receive a reminder.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if store.morningTaskBusy { ProgressView("Saving note…") }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Morning note")
                .onAppear { if store.isDemo || draft.completedAt != nil { notify=false } }
                .toolbar {
                    ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save") {
                        draft.text=draft.text.trimmingCharacters(in:.whitespacesAndNewlines)
                        Task { do { try await store.saveMorningTask(draft,notify:notify);dismiss() } catch { self.error=error.localizedDescription } }
                    }.disabled(draft.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || draft.text.count > 1000)}
                }.disabled(store.morningTaskBusy).interactiveDismissDisabled(store.morningTaskBusy)
        }
    }
}
