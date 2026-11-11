import SwiftUI
struct SoundBlendsView:View {
    @EnvironmentObject private var store:AppStore
    @State private var editor:SoundBlend?
    @State private var creating=false
    @State private var deleting:SoundBlend?
    var body:some View {
        LumaPage {
            SectionTitle(title:"Your room, your balance.",subtitle:"Combine up to three sounds, including your own audio.")
            Button("Create a sound blend",systemImage:"plus") { creating=true }.buttonStyle(.borderedProminent)
            if store.data.soundBlends.isEmpty { EmptyPanel(symbol:"slider.horizontal.3",title:"Start with a simple mix",text:"Try rain over brown noise, or a quiet layer behind one of your own tracks.") }
            BlendPlaybackControls(player:store.relaxation)
            ForEach(store.data.soundBlends) { blend in
                Surface {
                    Text(blend.name).font(.headline)
                    Text(blend.layers.map{store.relaxation.name(for:$0.source)}.joined(separator:" · ")).font(.subheadline).foregroundStyle(.secondary)
                    Text(blend.timerMinutes == 0 ? "Until stopped" : "\(blend.timerMinutes)-minute timer").font(.caption)
                    HStack {
                        Button("Play / stop",systemImage:"playpause") { store.perform { try store.relaxation.playBlend(blend) } }
                        Spacer();Button("Edit") { editor=blend };Button("Delete",role:.destructive) { deleting=blend }
                    }
                }
            }
            Text("Layer volumes are balanced under the master volume to avoid a sudden increase when adding sounds. With looping off, each track finishes at its own length. Microphone monitoring must be stopped before playback.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Saved sound blends")
            .sheet(isPresented:$creating) { BlendEditor() }
            .sheet(item:$editor) { BlendEditor(existing:$0) }
            .alert("Delete this mix?",isPresented:Binding(get:{deleting != nil},set:{if !$0 { deleting=nil }})) {
                Button("Delete",role:.destructive) { if let blend=deleting { store.perform { try store.transact{$0.soundBlends.removeAll{$0.id == blend.id}} };if store.relaxation.currentBlendID == blend.id { store.relaxation.stop() } };deleting=nil }
                Button("Cancel",role:.cancel) { deleting=nil }
            } message: { Text("The original sound files stay in your library.") }
    }
}
struct BlendPlaybackControls:View {
    @ObservedObject var player:RelaxationAudio
    @State private var result:String?
    var body:some View {
        if player.currentBlendID != nil {
            Surface {
                Text("Playing: \(player.title)").font(.headline)
                Slider(value:$player.volume,in:0...1) { Text("Master volume") }.accessibilityLabel("Master volume")
                ForEach(player.activeLayers) { layer in
                    VStack(alignment:.leading) {
                        Text(player.name(for:layer.source)).font(.subheadline)
                        Slider(value:Binding(get:{player.activeLayers.first{$0.source == layer.source}?.volume ?? 0},set:{player.setLayerVolume(layer.source,value:$0)}),in:0...1).accessibilityLabel("\(player.name(for:layer.source)) volume")
                    }
                }
                HStack { Button("Save this balance") { do { try player.saveCurrentBalance();result="Saved." } catch { result=error.localizedDescription } };Spacer();Button("Stop",systemImage:"stop.fill") { player.stop() } }
                if let result { Text(result).font(.caption) }
            }
        }
    }
}
private struct BlendEditor:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    var existing:SoundBlend?
    @State private var draft=SoundBlend(name:"",layers:[])
    @State private var loaded=false
    @State private var error:String?
    private var sources:[SleepSoundSource] { SleepSoundSource.builtInIDs.map{.builtIn($0)}+store.data.customSounds.map{.custom($0.id)} }
    var body:some View {
        NavigationStack {
            Form {
                Section("Name & playback") {
                    TextField("Mix name",text:$draft.name).accessibilityIdentifier("blend.name")
                    Picker("Timer",selection:$draft.timerMinutes) { Text("Until stopped").tag(0);ForEach([15,30,45,60,90,120],id:\.self){Text("\($0) minutes").tag($0)} }
                    Toggle("Loop each track",isOn:$draft.loop)
                }
                Section("Choose up to three layers") {
                    ForEach(sources,id:\.self) { source in
                        Toggle(store.relaxation.name(for:source),isOn:Binding(get:{draft.layers.contains{$0.source == source}},set:{value in
                            if value { if draft.layers.count < 3 { draft.layers.append(SoundLayer(source:source));error=nil } else { error="Choose at most three sounds." } }
                            else { draft.layers.removeAll{$0.source == source} }
                        }))
                    }
                }
                Section("Balance") {
                    ForEach(draft.layers) { layer in
                        VStack(alignment:.leading) {
                            Text(store.relaxation.name(for:layer.source))
                            Slider(value:Binding(get:{draft.layers.first{$0.source == layer.source}?.volume ?? 0},set:{value in if let i=draft.layers.firstIndex(where:{$0.source == layer.source}) { draft.layers[i].volume=value }}),in:0...1).accessibilityLabel("\(store.relaxation.name(for:layer.source)) volume")
                            if !sources.contains(layer.source) { Button("Remove missing sound",role:.destructive) { draft.layers.removeAll{$0.source == layer.source} } }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle(existing == nil ? "New sound blend" : "Edit sound blend")
                .onAppear { if !loaded { loaded=true;if let existing { draft=existing } } }
                .toolbar {
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save") {
                        do {
                            draft.name=draft.name.trimmingCharacters(in:.whitespacesAndNewlines);try draft.validate()
                            guard draft.layers.allSatisfy({sources.contains($0.source)}) else { throw LumaError.invalid("Replace or remove missing sounds before saving.") }
                            try store.transact { data in if let i=data.soundBlends.firstIndex(where:{$0.id == draft.id}) { data.soundBlends[i]=draft } else { data.soundBlends.append(draft) } }
                            if store.relaxation.currentBlendID == draft.id { store.relaxation.stop(reason:"Mix updated · play to hear changes") };dismiss()
                        } catch { self.error=error.localizedDescription }
                    }}
                }
        }
    }
}
