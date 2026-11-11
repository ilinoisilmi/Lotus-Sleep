import Foundation
import AVFoundation
import Combine

struct BuiltInSleepSound:Identifiable {
    let id:String
    let name:String
    let detail:String
    let symbol:String
    static let all:[BuiltInSleepSound]=[
        .init(id:"white",name:"White noise",detail:"Bright, even texture",symbol:"waveform"),
        .init(id:"pink",name:"Pink noise",detail:"Softer, balanced texture",symbol:"waveform.path"),
        .init(id:"brown",name:"Brown noise",detail:"Low, warm rumble",symbol:"water.waves"),
        .init(id:"rain",name:"Soft rain",detail:"An original rain-like sound",symbol:"cloud.rain"),
        .init(id:"ocean",name:"Slow waves",detail:"An original rolling surf texture",symbol:"water.waves"),
        .init(id:"fan",name:"Room fan",detail:"An original steady air texture",symbol:"fan")
    ]
}
@MainActor final class RelaxationAudio:ObservableObject {
    @Published private(set) var currentID:String?
    @Published private(set) var currentBlendID:UUID?
    @Published private(set) var activeLayers:[SoundLayer]=[]
    @Published private(set) var title="Choose a sound"
    @Published private(set) var endDate:Date?
    @Published private(set) var status="Ready when you are"
    @Published private(set) var isImporting=false
    @Published var volume:Float=0.2 { didSet { updateVolume() } }
    @Published var timerMinutes=30
    @Published var loop=true
    private weak var store:AppStore?
    private var players:[AVAudioPlayer]=[]
    private var playbackStartsAt=Date.distantPast
    private var timer:Timer?
    private var interruptions:NSObjectProtocol?
    private var route:NSObjectProtocol?
    private var reset:NSObjectProtocol?
    var isPlaying:Bool { currentID != nil }
    var folder:URL { AppStore.dataDirectory.appendingPathComponent("CustomSounds",isDirectory:true) }
    init(store:AppStore) { self.store=store }
    func name(for source:SleepSoundSource)->String {
        switch source {
        case .builtIn(let id):return BuiltInSleepSound.all.first{$0.id == id}?.name ?? "Unknown sound"
        case .custom(let id):return store?.data.customSounds.first{$0.id == id}?.name ?? "Missing imported sound"
        }
    }
    private func url(for source:SleepSoundSource) throws->URL {
        switch source {
        case .builtIn(let id):
            guard let url=Bundle.main.url(forResource:id,withExtension:"wav",subdirectory:"SleepSounds") else { throw LumaError.unavailable("This built-in sound is missing from the app build.") };return url
        case .custom(let id):
            guard let sound=store?.data.customSounds.first(where:{$0.id == id}) else { throw LumaError.unavailable("A mix uses an imported sound that is no longer available. Edit the mix and choose a replacement.") }
            let url=folder.appendingPathComponent(sound.fileName)
            guard FileManager.default.fileExists(atPath:url.path) else { throw LumaError.unavailable("The file for \(sound.name) is missing. Import it again and update any saved mixes.") };return url
        }
    }
    func playBuiltIn(_ sound:BuiltInSleepSound) throws { try play(layers:[SoundLayer(source:.builtIn(sound.id),volume:1)],id:sound.id,name:sound.name,blendID:nil,minutes:timerMinutes,loops:loop) }
    func playCustom(_ sound:CustomSleepSound) throws { try play(layers:[SoundLayer(source:.custom(sound.id),volume:1)],id:sound.id.uuidString,name:sound.name,blendID:nil,minutes:timerMinutes,loops:loop) }
    func playBlend(_ blend:SoundBlend) throws {
        try blend.validate()
        try play(layers:blend.layers,id:"blend:"+blend.id.uuidString,name:blend.name,blendID:blend.id,minutes:blend.timerMinutes,loops:blend.loop)
    }
    private func play(layers:[SoundLayer],id:String,name:String,blendID:UUID?,minutes:Int,loops:Bool) throws {
        guard let store,!store.audio.isRunning,!store.audio.isStarting else { throw LumaError.unavailable("Stop microphone monitoring before playing sleep sounds. Speaker audio can trigger sound events.") }
        if currentID == id { stop();return }
        // Validate every file before replacing the current playback; never silently omit a missing layer.
        let urls=try layers.map{try url(for:$0.source)}
        stop()
        do {
            let session=AVAudioSession.sharedInstance()
            try session.setCategory(.playback,mode:.default);try session.setActive(true)
            for url in urls {
                let audio=try AVAudioPlayer(contentsOf:url);audio.numberOfLoops=loops ? -1 : 0
                guard audio.prepareToPlay() else { throw LumaError.unavailable("One of these audio files cannot be decoded.") }
                players.append(audio)
            }
            activeLayers=layers;timerMinutes=minutes;loop=loops
            endDate=minutes == 0 ? nil : Date().addingTimeInterval(Double(minutes)*60+0.1)
            updateVolume()
            let deviceTime=(players.first?.deviceCurrentTime ?? 0)+0.1
            for audio in players { guard audio.play(atTime:deviceTime) else { throw LumaError.unavailable("This sound mix could not start.") } }
            playbackStartsAt=Date().addingTimeInterval(0.15)
            currentID=id;currentBlendID=blendID;title=name
            status=endDate == nil ? "Playing until stopped" : "Playing · fades during the final 10 seconds"
            let tick=Timer(timeInterval:0.25,repeats:true) { [weak self] _ in Task { @MainActor in self?.tick() } }
            RunLoop.main.add(tick,forMode:.common);timer=tick
            interruptions=NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] note in
                guard let type=note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,type == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor in self?.stop(reason:"Interrupted · tap a sound to restart") }
            }
            route=NotificationCenter.default.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.stop(reason:"Audio route changed · tap to restart") } }
            reset=NotificationCenter.default.addObserver(forName:AVAudioSession.mediaServicesWereResetNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.stop(reason:"Audio system reset · tap to restart") } }
        } catch { stop();try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation);throw error }
    }
    func setLayerVolume(_ source:SleepSoundSource,value:Double) {
        guard let index=activeLayers.firstIndex(where:{$0.source == source}) else { return }
        activeLayers[index].volume=min(1,max(0,value));updateVolume()
    }
    func saveCurrentBalance() throws {
        guard let store,let id=currentBlendID,let index=store.data.soundBlends.firstIndex(where:{$0.id == id}) else { throw LumaError.unavailable("Play a saved mix first.") }
        var blend=store.data.soundBlends[index];blend.layers=activeLayers;try blend.validate()
        try store.transact{$0.soundBlends[index]=blend};status="Mix balance saved"
    }
    private func updateVolume() {
        let fade=endDate.map{min(1,max(0,$0.timeIntervalSinceNow/10))} ?? 1
        let gains=SoundBlend.gains(layers:activeLayers,master:Double(volume),fade:fade)
        for (index,audio) in players.enumerated() where index < gains.count { audio.volume=Float(gains[index]) }
    }
    private func tick() {
        guard !players.isEmpty else { return }
        if let endDate,endDate <= Date() { stop(reason:"Sleep timer finished");return }
        if Date() > playbackStartsAt,!players.contains(where:{$0.isPlaying}) { stop(reason:"Tracks finished");return }
        updateVolume()
    }
    func stop(reason:String="Stopped") {
        let hadPlayer = !players.isEmpty
        timer?.invalidate();timer=nil;players.forEach{$0.stop()};players=[]
        currentID=nil;currentBlendID=nil;activeLayers=[];endDate=nil;status=reason
        for observer in [interruptions,route,reset].compactMap({$0}) { NotificationCenter.default.removeObserver(observer) }
        interruptions=nil;route=nil;reset=nil
        if hadPlayer { try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation) }
    }
    func importFile(_ url:URL) async throws {
        guard let store,!store.isDemo,!isImporting else { throw LumaError.unavailable("Exit demo mode and finish any current import first.") }
        guard store.data.customSounds.count < 50 else { throw LumaError.invalid("The library holds up to 50 custom sounds. Delete one before importing another.") }
        isImporting=true;defer{isImporting=false}
        let destination=folder
        let sound=try await Task.detached(priority:.userInitiated) { try Self.prepareImport(url,folder:destination) }.value
        do { try store.transact{$0.customSounds.append(sound)} }
        catch { try? FileManager.default.removeItem(at:destination.appendingPathComponent(sound.fileName));throw error }
        status="Imported \(sound.name)"
    }
    nonisolated private static func prepareImport(_ url:URL,folder:URL) throws->CustomSleepSound {
        let scoped=url.startAccessingSecurityScopedResource();defer{if scoped { url.stopAccessingSecurityScopedResource() }}
        let ext=url.pathExtension.lowercased()
        guard ["mp3","m4a","wav"].contains(ext) else { throw LumaError.invalid("Choose an MP3, M4A or WAV file.") }
        let values=try url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey])
        guard values.isRegularFile == true,let size=values.fileSize,size > 0,size <= 100*1024*1024 else { throw LumaError.invalid("Choose an audio file smaller than 100 MB.") }
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication])
        var directory=folder;var resource=URLResourceValues();resource.isExcludedFromBackup=true;try directory.setResourceValues(resource)
        let capacity=try folder.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard capacity > Int64(size)+100*1024*1024 else { throw LumaError.unavailable("Free more storage before importing this sound.") }
        let id=UUID(),fileName=id.uuidString+"."+ext,destination=folder.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at:url,to:destination)
            try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:destination.path)
            let audio=try AVAudioPlayer(contentsOf:destination)
            let title=String(url.deletingPathExtension().lastPathComponent.prefix(100))
            let sound=CustomSleepSound(id:id,name:title.isEmpty ? "Custom sound" : title,fileName:fileName,duration:audio.duration)
            try sound.validate();return sound
        } catch { try? FileManager.default.removeItem(at:destination);throw error }
    }
    func delete(_ sound:CustomSleepSound) throws {
        guard let store,!store.isDemo else { throw LumaError.unavailable("Exit demo mode to delete imported sounds.") }
        if activeLayers.contains(where:{$0.source == .custom(sound.id)}) { stop() }
        // Remove the metadata first. If file cleanup fails, the next foreground cleanup retries it.
        try store.transact{$0.customSounds.removeAll{$0.id == sound.id}}
        let url=folder.appendingPathComponent(sound.fileName)
        if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
    }
    func cleanOrphans() {
        guard let store,!store.isDemo,!isImporting else { return }
        let retained=Set(store.data.customSounds.map(\.fileName))
        guard let files=try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil) else { return }
        for url in files where !retained.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at:url) }
    }
}
