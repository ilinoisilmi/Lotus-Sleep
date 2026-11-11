import SwiftUI
import AVFoundation
import Combine

struct LiveSoundWaveform:View {
    @ObservedObject var monitor:AudioMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack { Label(monitor.isRunning ? "Microphone live" : "Microphone off",systemImage:monitor.isRunning ? "mic.fill" : "mic.slash").font(.caption.weight(.semibold)); Spacer(); if monitor.isRunning { Text("\(monitor.currentDB.formatted(.number.precision(.fractionLength(0)))) dBFS").font(.caption.monospacedDigit()).foregroundStyle(.secondary) } }
            if reduceMotion {
                ProgressView(value:monitor.isRunning ? Double(monitor.levels.last ?? 0) : 0).tint(Luma.lavender).frame(height:60)
            } else {
                Canvas { context,size in
                    let gap:CGFloat=3
                    let width=max(1,(size.width-gap*39)/40)
                    for (index,level) in monitor.levels.enumerated() {
                        let height=max(3,CGFloat(level)*size.height)
                        let rect=CGRect(x:CGFloat(index)*(width+gap),y:(size.height-height)/2,width:width,height:height)
                        context.fill(Path(roundedRect:rect,cornerRadius:width/2),with:.color(monitor.isRunning ? Luma.lavender : .gray.opacity(0.35)))
                    }
                }.frame(height:64).accessibilityHidden(true)
            }
            Text(monitor.isRunning ? "\(monitor.eventCount) saved sound events · levels are not sleep stages" : "Start listening to see real microphone levels.").font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children:.combine)
    }
}

struct NightSoundPanel:View {
    @EnvironmentObject private var store:AppStore
    @ObservedObject var monitor:AudioMonitor
    var beforeStart:()->Void = {}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            LiveSoundWaveform(monitor:monitor)
            Toggle("Save audio for replay",isOn:Binding(get:{store.data.preferences.retainAudio},set:{value in store.updatePreferences{$0.retainAudio=value}})).disabled(monitor.isRunning || monitor.isStarting)
            Text(store.data.preferences.retainAudio ? "Saves a full recording on this iPhone; event buttons replay short sections. Record only with everyone nearby’s agreement." : "Only sound timestamps and levels are saved. Enable replay before starting if you want to hear events later.").font(.caption).foregroundStyle(.secondary)
            AudioControls(monitor:monitor,beforeStart:beforeStart)
        }.padding(18).background(Color.white.opacity(0.05),in:RoundedRectangle(cornerRadius:22))
    }
}

@MainActor final class SoundPlayback:ObservableObject {
    @Published private(set) var playingID:UUID?
    @Published private(set) var progress:Double=0
    @Published private(set) var duration:Double=0
    private var player:AVAudioPlayer?
    private var timer:Timer?
    private var interruptions:NSObjectProtocol?
    private var route:NSObjectProtocol?
    private var start:Double=0
    private var end:Double=0
    func play(url:URL,id:UUID,offset:Double=0,length:Double?=nil) throws {
        if playingID == id { stop(); return }
        stop()
        do {
            let session=AVAudioSession.sharedInstance()
            try session.setCategory(.playback,mode:.default)
            try session.setActive(true)
            let audio=try AVAudioPlayer(contentsOf:url)
            start=min(max(0,offset),audio.duration)
            end=min(audio.duration,length.map{start+max(0,$0)} ?? audio.duration)
            guard end > start else { throw LumaError.unavailable("This event is outside the saved recording.") }
            audio.currentTime=start; audio.prepareToPlay()
            guard audio.play() else { throw LumaError.unavailable("The recording could not be played.") }
            player=audio; playingID=id; duration=end-start; progress=0
            let tick=Timer(timeInterval:0.1,repeats:true) { [weak self] _ in
                Task { @MainActor in
                    guard let self,let audio=self.player else { return }
                    self.progress=max(0,audio.currentTime-self.start)
                    if !audio.isPlaying || audio.currentTime >= self.end { self.stop() }
                }
            }
            RunLoop.main.add(tick,forMode:.common); timer=tick
            interruptions=NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] note in
                guard let type=note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,type == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor in self?.stop() }
            }
            route=NotificationCenter.default.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.stop() } }
        } catch {
            stop()
            // Opening a file can fail after the audio session was activated but before player exists.
            try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
            throw error
        }
    }
    func stop() {
        let wasPlaying=player != nil
        timer?.invalidate(); timer=nil; player?.stop(); player=nil; playingID=nil; progress=0
        for observer in [interruptions,route].compactMap({$0}) { NotificationCenter.default.removeObserver(observer) }
        interruptions=nil;route=nil
        if wasPlaying { try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation) }
    }
}

struct SoundSessionCard:View {
    @EnvironmentObject private var store:AppStore
    let session:AudioSession
    @ObservedObject var playback:SoundPlayback
    @State private var expanded=false
    @State private var page=0
    private var pageCount:Int { max(1,(session.events.count+23)/24) }
    private var visibleEvents:[SoundEvent] {
        Array(session.events.dropFirst(expanded ? min(page,pageCount-1)*24 : 0).prefix(expanded ? 24 : 6))
    }
    private var url:URL? {
        guard let name=session.fileName else { return nil }
        let url=store.audio.folder.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath:url.path) ? url : nil
    }
    var body:some View {
        Surface {
            Text(session.start.formatted(date:.abbreviated,time:.shortened)).font(.headline)
            Text(session.status).font(.caption).foregroundStyle(.secondary)
            HStack { Label("\(session.events.count) sound events",systemImage:"waveform"); Spacer(); if session.retainsAudio { Image(systemName:"internaldrive").accessibilityLabel("Audio retention was enabled") } }.font(.subheadline)
            if let url, session.end != nil {
                Button(playback.playingID == session.id ? "Stop recording playback" : "Play full recording",systemImage:playback.playingID == session.id ? "stop.fill" : "play.fill") { play(url,id:session.id) }.disabled(store.audio.isRunning || store.audio.isStarting)
                ShareLink("Export recording",item:url)
            } else {
                Text(session.end == nil ? "End monitoring before replaying audio." : "No saved audio. Replay must be enabled before recording; expired or deleted audio cannot be recovered.").font(.caption).foregroundStyle(.secondary)
            }
            if session.events.isEmpty { Text("No events saved. The first five seconds calibrate the room. Silence does not prove sleep.").font(.caption).foregroundStyle(.secondary) }
            ForEach(visibleEvents) { event in
                HStack(alignment:.center) {
                    VStack(alignment:.leading,spacing:4) {
                        Text(event.date.formatted(date:.omitted,time:.standard)).font(.subheadline.monospacedDigit())
                        Text("\(event.duration.formatted(.number.precision(.fractionLength(1))))s · \(event.peakDB.formatted(.number.precision(.fractionLength(0)))) dBFS").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url,session.end != nil {
                        Button { play(url,id:event.id,event:event) } label: {
                            Label(playback.playingID == event.id ? "Stop" : "Replay",systemImage:playback.playingID == event.id ? "stop.fill" : "play.fill")
                        }.buttonStyle(.bordered).disabled(store.audio.isRunning || store.audio.isStarting)
                    }
                }
                if playback.playingID == event.id { ProgressView(value:min(playback.progress,playback.duration),total:max(0.1,playback.duration)).tint(Luma.lavender) }
            }
            if session.events.count > 6 {
                if expanded {
                    HStack {
                        Button("Previous") { page=max(0,page-1) }.disabled(page == 0)
                        Spacer()
                        Text("\(min(page,pageCount-1)+1) / \(pageCount)").font(.caption.monospacedDigit())
                        Spacer()
                        Button("Next") { page=min(pageCount-1,page+1) }.disabled(page >= pageCount-1)
                    }
                    Button("Show fewer events") { expanded=false; page=0 }
                } else {
                    Button("Browse \(session.events.count) events") { expanded=true; page=0 }
                }
            }
            Text("A sound may come from you, another person or the room. These events do not identify wakefulness or snoring.").font(.caption).foregroundStyle(.secondary)
            Button("Delete recording & events",role:.destructive) { playback.stop(); store.perform { try store.audio.deleteRecording(session.id) } }
        }
    }
    private func play(_ url:URL,id:UUID,event:SoundEvent?=nil) {
        guard !store.audio.isRunning, !store.audio.isStarting else { store.message="Stop monitoring before playing a recording."; return }
        store.relaxation.stop()
        store.perform {
            if let event {
                let offset=event.recordingOffset ?? event.date.timeIntervalSince(session.start)
                let start=max(0,offset-1)
                try playback.play(url:url,id:id,offset:start,length:min(32,event.duration+(offset-start)+1))
            } else { try playback.play(url:url,id:id) }
        }
    }
}
