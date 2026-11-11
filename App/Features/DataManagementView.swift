import SwiftUI
import UniformTypeIdentifiers
struct DataFile:FileDocument {
    static var readableContentTypes:[UTType] { [.json,.commaSeparatedText,.plainText,.data] }
    var data:Data
    init(data:Data=Data()) { self.data=data }
    init(configuration:ReadConfiguration) throws { data=configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration:WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}
func readScoped(_ url:URL,limit:Int)->Data? {
    let access=url.startAccessingSecurityScopedResource(); defer{if access{url.stopAccessingSecurityScopedResource()}}
    guard let values=try? url.resourceValues(forKeys:[.fileSizeKey]),let size=values.fileSize,size<=limit else{return nil}
    return try? Data(contentsOf:url)
}
struct ImportView:View {
    @EnvironmentObject private var store:AppStore
    @State private var choosing=false
    @State private var preview:ImportPreview?
    @State private var status:String?
    @State private var exporting=false
    @State private var file=DataFile()
    @State private var contentType=UTType.json
    @State private var filename="luma-example.json"
    var body:some View {
        LumaPage {
            SectionTitle(title:"Bring your history along.",subtitle:"Preview every import before saving.")
            Text("Use Lotus's documented CSV or JSON sleep-log format. Dates require an explicit UTC offset or Z and an IANA timezone. Apple Health XML exports are not supported in this version.")
            PrimaryButton(title:"Choose CSV or JSON",symbol:"doc.badge.plus") { choosing=true }
            HStack { Button("CSV example") { file=DataFile(data:SleepLogFormat.exampleCSV());contentType = .commaSeparatedText;filename="luma-example.csv";exporting=true }; Spacer(); Button("JSON example") { file=DataFile(data:SleepLogFormat.exampleJSON());contentType = .json;filename="luma-example.json";exporting=true } }
            if let preview {
                Surface {
                    Text("Import preview").font(.headline)
                    LabeledContent("Ready to add",value:"\(preview.accepted.count)")
                    LabeledContent("Duplicates skipped",value:"\(preview.duplicates)")
                    LabeledContent("Rejected rows",value:"\(preview.rejected.count)")
                    if let first=preview.accepted.map(\.start).min(),let last=preview.accepted.map(\.end).max() { Text("\(first.formatted(date:.abbreviated,time:.shortened)) to \(last.formatted(date:.abbreviated,time:.shortened))").font(.caption) }
                    ForEach(Array(preview.accepted.prefix(8))) { r in Text("\(r.sourceName) · \(r.stage.label) · \(r.start.formatted(date:.abbreviated,time:.shortened))").font(.caption) }
                    Button("Import \(preview.accepted.count) valid records") {
                        store.perform { try store.transact { s in
                            let known=Set(s.records.map(\.id)); s.records.append(contentsOf:preview.accepted.filter{!known.contains($0.id)})
                        };status="Import saved. \(preview.rejected.count) rows were not imported.";self.preview=nil }
                    }.buttonStyle(.borderedProminent).tint(.indigo).disabled(preview.accepted.isEmpty)
                }
                if !preview.rejected.isEmpty { DisclosureGroup("Rejected rows") { ForEach(preview.rejected) { issue in Text("Row \(issue.row): \(issue.message)").font(.caption).padding(.vertical,4) } } }
            }
            if let status { Text(status).foregroundStyle(.secondary) }
        }.navigationTitle("Import")
        .fileImporter(isPresented:$choosing,allowedContentTypes:[.json,.commaSeparatedText,.plainText]) { result in
            do { let url=try result.get(); guard let bytes=readScoped(url,limit:10*1024*1024) else{throw LumaError.invalid("The file could not be read or exceeds 10 MB.")}; preview=try SleepLogFormat.preview(bytes,format:url.pathExtension,existing:store.data.records); status=nil } catch{status=error.localizedDescription}
        }
        .fileExporter(isPresented:$exporting,document:file,contentType:contentType,defaultFilename:filename) { result in if case .failure(let error)=result{status=error.localizedDescription} }
    }
}
struct DataManagementView:View {
    @EnvironmentObject private var store:AppStore
    @State private var exporting=false
    @State private var importing=false
    @State private var confirmRestore=false
    @State private var confirmDelete=false
    @State private var restoreBytes:Data?
    @State private var restoreSummary=""
    @State private var file=DataFile()
    @State private var contentType=UTType.json
    @State private var filename="LotusSleep-backup.json"
    @State private var status:String?
    var body:some View {
        Form {
            Section("Export") {
                Button("Export complete JSON backup") { store.perform{file=DataFile(data:try store.backup());contentType = .json;filename=store.isDemo ? "LotusSleep-DEMO-backup.json" : "LotusSleep-backup.json";exporting=true} }
                Button("Export current sleep records as CSV") { file=DataFile(data:SleepLogFormat.exportCSV(store.data.effectiveRecords));contentType = .commaSeparatedText;filename=store.isDemo ? "LumaSleep-DEMO-log.csv" : "LotusSleep-log.csv";exporting=true }
                Text("JSON preserves diary revisions, records, notes, your profile, caffeine logs, morning notes, experiments, companions, sound blends, settings and audio metadata. CSV is a flat sleep log. Neither includes recordings or imported sound files. Exports are unencrypted and may contain sensitive notes.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Restore") {
                Button("Choose a Lotus JSON backup") { importing=true }.disabled(store.isDemo)
                Text("Restore replaces local history and profile after a preview. Reminders and widgets are turned off, including morning-note reminders. Existing recordings and imported sound copies are removed; reimport your originals from Files and replace missing layers in saved blends. A JSON rollback copy is saved. Reconnect Health to sync this device’s data.").font(.caption).foregroundStyle(.secondary)
                let rollback=AppStore.dataDirectory.appendingPathComponent("before-restore.json")
                if FileManager.default.fileExists(atPath:rollback.path) { ShareLink("Export the backup from before restore",item:rollback) }
            }
            Section("Erase") {
                Button("Delete all Lotus data",role:.destructive) { confirmDelete=true }
                Text("Deletes local history, notes, sound files, saved revisions, check-ins and the rollback copy. Cancels Lotus reminders and its wake alarm. Apple Health and previously exported files remain under your control.").font(.caption).foregroundStyle(.secondary)
            }
            if let status { Section{Text(status)} }
        }.navigationTitle("Your data")
        .fileExporter(isPresented:$exporting,document:file,contentType:contentType,defaultFilename:filename) { result in if case .failure(let error)=result{status=error.localizedDescription} }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in
            do { let url=try result.get();guard let bytes=readScoped(url,limit:50*1024*1024) else{throw LumaError.invalid("Backup could not be read or exceeds 50 MB.")};let s=try SnapshotCodec.decode(bytes);restoreSummary="Replace local history with \(s.diaries.count) diary entries and \(s.records.count) source records, \(s.morningTasks.count) morning notes and \(s.experiments.count) experiments? Existing recordings and imported sound copies will be removed; keep the originals before continuing.";restoreBytes=bytes;confirmRestore=true }catch{status=error.localizedDescription}
        }
        .confirmationDialog("Restore backup?",isPresented:$confirmRestore,titleVisibility:.visible) { Button("Replace local history",role:.destructive) { do{if let bytes=restoreBytes{try store.restore(bytes);status="Backup restored."}}catch{status=error.localizedDescription};restoreBytes=nil }; Button("Cancel",role:.cancel){restoreBytes=nil} } message:{Text(restoreSummary)}
        .confirmationDialog("Delete all Lotus data?",isPresented:$confirmDelete,titleVisibility:.visible) { Button("Delete all data",role:.destructive) { Task{do{try await store.deleteAll();status="Lotus data deleted."}catch{status=error.localizedDescription}} } } message:{Text("This cannot be undone unless you have exported a backup.")}
    }
}
struct RecoveryView:View {
    let error:String
    var body:some View {
        NavigationStack { LumaPage { EmptyPanel(symbol:"externaldrive.badge.exclamationmark",title:"Your history needs attention",text:error); let url=AppStore.dataDirectory.appendingPathComponent("sleep-v2.json"); if FileManager.default.fileExists(atPath:url.path){ShareLink("Export existing data file",item:url)};NavigationLink("Restore from a backup"){DataManagementView()} }.navigationTitle("Data recovery") }
    }
}
struct TimezonePicker:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var search=""
    var body:some View { List(TimeZone.knownTimeZoneIdentifiers.filter{search.isEmpty || $0.localizedCaseInsensitiveContains(search)},id:\.self) { zone in Button(zone) { store.updatePreferences{$0.reportingTimeZoneID=zone};dismiss() } }.searchable(text:$search,prompt:"City or region").navigationTitle("Reporting timezone") }
}
