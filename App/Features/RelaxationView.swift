import SwiftUI
import UniformTypeIdentifiers

struct RelaxationView:View {
    @EnvironmentObject private var store:AppStore
    var body:some View { RelaxationContent(player:store.relaxation) }
}
private struct RelaxationContent:View {
    @EnvironmentObject private var store:AppStore
    @ObservedObject var player:RelaxationAudio
    @State private var importing=false
    @State private var deleting:CustomSleepSound?
    @State private var error:String?
    var body:some View {
        LumaPage {
            SectionTitle(title:"A softer place to land.",subtitle:"Six original textures, or a sound of your own.")
            if let error { Label(error,systemImage:"exclamationmark.circle").foregroundStyle(Luma.warm) }
            Surface {
                Label(player.currentID == nil ? "Nothing playing" : player.title,systemImage:"speaker.wave.2").font(.headline)
                Text(player.status).font(.caption).foregroundStyle(.secondary)
                if let end=player.endDate { Text("Stops at \(end.formatted(date:.omitted,time:.shortened))").font(.subheadline) }
                HStack { Image(systemName:"speaker"); Slider(value:$player.volume,in:0...1).accessibilityLabel("Sound volume"); Image(systemName:"speaker.wave.3") }
                Picker("Sleep timer",selection:$player.timerMinutes) { Text("Until stopped").tag(0);ForEach([15,30,45,60,90,120],id:\.self){Text("\($0) minutes").tag($0)} }.disabled(player.currentID != nil)
                Toggle("Loop the sound",isOn:$player.loop).disabled(player.currentID != nil)
                if player.currentID != nil { Button("Stop sound",systemImage:"stop.fill") { player.stop() } }
                Text("Start quietly. The slider changes app volume; your iPhone’s volume also applies. The timer fades out over its final 10 seconds. Calls, route changes and force-quitting can stop playback.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Pause sleep sounds before microphone monitoring. The speaker would otherwise be recorded as room noise.").font(.caption).foregroundStyle(.secondary)
            NavigationLink { SoundBlendsView() } label: { Label("Saved sound blends",systemImage:"slider.horizontal.3") }
            BlendPlaybackControls(player:player)
            SectionTitle(title:"Lotus sounds",subtitle:"Generated audio · no downloaded recordings")
            ForEach(BuiltInSleepSound.all) { sound in
                Button { perform { try player.playBuiltIn(sound) } } label: {
                    HStack(spacing:16) {
                        Image(systemName:sound.symbol).font(.title2).foregroundStyle(Luma.lavender).frame(width:32)
                        VStack(alignment:.leading,spacing:4) { Text(sound.name).font(.headline); Text(sound.detail).font(.caption).foregroundStyle(.secondary) }
                        Spacer();Image(systemName:player.currentID == sound.id ? "stop.circle.fill" : "play.circle")
                    }.padding(16).background(Color.primary.opacity(0.045),in:RoundedRectangle(cornerRadius:18))
                }.buttonStyle(.plain).accessibilityLabel("\(player.currentID == sound.id ? "Stop" : "Play") \(sound.name)")
            }
            SectionTitle(title:"Your own sounds")
            Button("Import an MP3, M4A or WAV",systemImage:"square.and.arrow.down") { importing=true }.disabled(player.isImporting || store.isDemo)
            if player.isImporting { ProgressView("Copying and checking audio…") }
            if store.data.customSounds.isEmpty { Text("Choose audio from the Files app. Lotus copies it into your private sound library for offline playback.").foregroundStyle(.secondary) }
            ForEach(store.data.customSounds) { sound in
                Surface {
                    Text(sound.name).font(.headline)
                    Text(Luma.duration(sound.duration)).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(player.currentID == sound.id.uuidString ? "Stop" : "Play",systemImage:player.currentID == sound.id.uuidString ? "stop.fill" : "play.fill") { perform { try player.playCustom(sound) } }
                        Spacer();Button("Delete",role:.destructive) { deleting=sound }
                    }
                }
            }
            Text("Up to 50 files, 100 MB and 2 hours each. Use audio you have permission to use. Imported audio is not included in JSON backups; keep the original files. Sound preferences differ, and audio does not guarantee better sleep.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Sleep sounds").navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented:$importing,allowedContentTypes:[.audio],allowsMultipleSelection:false) { result in
                do { if let url=try result.get().first { Task { do { self.error=nil;try await player.importFile(url) } catch { self.error=error.localizedDescription } } } } catch { self.error=error.localizedDescription }
            }
            .alert("Delete this imported sound?",isPresented:Binding(get:{deleting != nil},set:{if !$0 { deleting=nil }})) {
                Button("Delete",role:.destructive) { if let sound=deleting { perform { try player.delete(sound) } };deleting=nil }
                Button("Cancel",role:.cancel) { deleting=nil }
            } message: { Text("The copy inside Lotus will be removed. Saved mixes using it will need a replacement. Your original in Files stays available.") }
    }
    private func perform(_ action:() throws->Void) { do { error=nil;try action() } catch { self.error=error.localizedDescription } }
}
