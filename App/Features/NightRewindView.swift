import SwiftUI
struct NightRewindView:View {
    @EnvironmentObject private var store:AppStore
    let day:SleepDay
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var playback=SoundPlayback()
    @State private var page=0
    @State private var filter="All"
    var body:some View {
        let all=NightRewind.items(snapshot:store.data,window:day.window,now:store.now)
        let items=all.filter{filter == "All" || $0.kind.rawValue == filter}
        let pages=max(1,(items.count+29)/30)
        LumaPage {
            SectionTitle(title:"Your night, in order.",subtitle:Luma.day(day.date,zoneID:store.data.preferences.reportingTimeZoneID))
            Text("Sleep evidence, your wake-up notes and room sounds stay separate. Gaps are unknown; sounds never prove that you were awake.").font(.subheadline).foregroundStyle(.secondary)
            Picker("Show",selection:$filter) { Text("All").tag("All");ForEach(RewindKind.allCases,id:\.self){Text($0.rawValue).tag($0.rawValue)} }.onChange(of:filter){_,_ in page=0}
            ForEach(Array(items.dropFirst(min(page,pages-1)*30).prefix(30))) { item in
                Surface {
                    HStack { Image(systemName:item.kind == .sound ? "waveform" : item.kind == .wake ? "moon.zzz" : item.kind == .unknown ? "questionmark.circle" : "moon.stars");Text(item.title).font(.headline) }
                    Text("\(item.start.formatted(date:.omitted,time:.shortened)) – \(item.end.formatted(date:.omitted,time:.shortened))").font(.caption.monospacedDigit())
                    Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                    if item.kind == .sound {
                        if let session=store.data.audioSessions.first(where:{$0.id == item.sessionID}),let event=session.events.first(where:{$0.id == item.eventID}),let name=session.fileName,session.end != nil,FileManager.default.fileExists(atPath:store.audio.folder.appendingPathComponent(name).path) {
                            Button(playback.playingID == event.id ? "Stop replay" : "Replay this sound",systemImage:playback.playingID == event.id ? "stop.fill" : "play.fill") {
                                guard !store.audio.isRunning,!store.audio.isStarting else { store.message="Stop monitoring before replaying a sound.";return }
                                store.relaxation.stop()
                                let offset=event.recordingOffset ?? event.date.timeIntervalSince(session.start),start=max(0,offset-1)
                                store.perform { try playback.play(url:store.audio.folder.appendingPathComponent(name),id:event.id,offset:start,length:min(32,event.duration+(offset-start)+1)) }
                            }
                            if playback.playingID == event.id { ProgressView(value:min(playback.progress,playback.duration),total:max(0.1,playback.duration)) }
                        } else { Text("Replay unavailable: audio was not retained, has expired, or monitoring is still active.").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            if items.isEmpty { Text("No events of this type for this sleep day.") }
            HStack { Button("Previous"){page=max(0,page-1)}.disabled(page==0);Spacer();Text("\(min(page,pages-1)+1) / \(pages)");Spacer();Button("Next"){page=min(pages-1,page+1)}.disabled(page>=pages-1) }
            Text("Times use this iPhone’s timezone. Recorded stages retain their source; your manual logs are estimates.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Night Rewind").navigationBarTitleDisplayMode(.inline)
            .onDisappear{playback.stop()}
            .onChange(of:scenePhase){_,phase in if phase != .active { playback.stop() }}
    }
}
