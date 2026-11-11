import Foundation
import AVFoundation
import Accelerate
import Combine

/// Event-only default: audio buffers are reduced to level statistics in memory, never uploaded.
/// Retention writes one bounded recording, not automatically classified snore clips.
@MainActor final class AudioMonitor:ObservableObject {
    @Published private(set) var isRunning=false
    @Published private(set) var status="Sound monitoring is off"
    @Published private(set) var levels:[Float]=Array(repeating:0,count:40)
    @Published private(set) var currentDB:Float = -80
    @Published private(set) var eventCount=0
    @Published private(set) var isStarting=false
    private weak var store:AppStore?
    private let engine=AVAudioEngine()
    private var processor:LevelProcessor?
    private var sessionID:UUID?
    private var interruption: NSObjectProtocol?
    private var routeChange:NSObjectProtocol?
    private var mediaReset:NSObjectProtocol?
    private var tapInstalled=false
    init(store:AppStore) { self.store=store }
    var folder:URL { AppStore.dataDirectory.appendingPathComponent("Audio",isDirectory:true) }
    func start(retain:Bool) async throws {
        guard let store, !store.isDemo else { throw LumaError.unavailable("Microphone use is disabled in demo mode.") }
        guard !store.relaxation.isPlaying else { throw LumaError.unavailable("Pause sleep sounds before monitoring. Speaker audio would trigger your sound journal.") }
        guard !isRunning, !isStarting else { return }
        isStarting=true; defer { isStarting=false }
        let allowed=await withCheckedContinuation { continuation in AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning:$0) } }
        guard allowed else { throw LumaError.unavailable("Microphone permission is off. Enable it in iPhone Settings to monitor sound events.") }
        let session=AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,mode:.measurement,options:[.defaultToSpeaker,.mixWithOthers])
        try session.setActive(true)
        let input=engine.inputNode, format=input.outputFormat(forBus:0)
        guard format.sampleRate>0,format.channelCount>0 else { try? session.setActive(false); throw LumaError.unavailable("No microphone input is available.") }
        var metadata=AudioSession(start:store.now); metadata.retainsAudio=retain
        var file:AVAudioFile?
        do {
            if retain {
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication])
                var folderURL=folder; var resource=URLResourceValues(); resource.isExcludedFromBackup=true; try folderURL.setResourceValues(resource)
                let filename=metadata.id.uuidString+".m4a", url=folder.appendingPathComponent(filename)
                let capacity=try folder.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
                guard capacity>500*1024*1024 else { throw LumaError.unavailable("Free at least 500 MB before retaining a recording. Event-only mode does not keep raw audio.") }
                file=try AVAudioFile(forWriting:url,settings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:format.sampleRate,AVNumberOfChannelsKey:format.channelCount,AVEncoderBitRateKey:64000])
                try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:url.path)
                metadata.fileName=filename
            }
            try store.transact{$0.audioSessions.append(metadata)}
            sessionID=metadata.id
            let id=metadata.id
            levels=Array(repeating:0,count:40); eventCount=0
            let p=LevelProcessor(sampleRate:format.sampleRate,file:file,start:metadata.start,levelCallback:{ [weak self] db in
                Task { @MainActor in
                    guard let self,self.sessionID == id,self.isRunning else { return }
                    self.currentDB=db
                    self.levels.append(min(1,max(0,(db+65)/55)))
                    self.levels=Array(self.levels.suffix(40))
                }
            }) { [weak self] events,reason in
                Task { @MainActor in
                    guard self?.sessionID == id else { return }
                    self?.receive(events:events,stopReason:reason)
                }
            }
            processor=p
            input.installTap(onBus:0,bufferSize:4096,format:format) { buffer,_ in p.consume(buffer) }
            tapInstalled=true; engine.prepare(); try engine.start(); isRunning=true; status="Listening for sound events"
            interruption=NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:.main) { [weak self] notification in
                guard let raw=notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor in self?.stop(reason:"Interrupted; start again when ready") }
            }
            routeChange=NotificationCenter.default.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:.main) { [weak self] _ in
                Task { @MainActor in self?.stop(reason:"Audio route changed; review and restart") }
            }
            mediaReset=NotificationCenter.default.addObserver(forName:AVAudioSession.mediaServicesWereResetNotification,object:nil,queue:.main) { [weak self] _ in
                Task { @MainActor in self?.stop(reason:"Audio system reset; review and restart") }
            }
        } catch {
            if sessionID == nil, let name=metadata.fileName { try? FileManager.default.removeItem(at:folder.appendingPathComponent(name)) }
            stop(reason:"Could not start recording")
            try? session.setActive(false,options:.notifyOthersOnDeactivation)
            throw error
        }
    }
    private func receive(events:[SoundEvent],stopReason:String?) {
        guard let store, let id=sessionID else { return }
        do {
            if !events.isEmpty { try store.transact { s in if let i=s.audioSessions.firstIndex(where:{$0.id == id}) { s.audioSessions[i].events.append(contentsOf:events) } }; eventCount+=events.count }
        }
        catch { stop(reason:"Storage error; recording stopped"); store.message="Sound metadata could not be saved. \(error.localizedDescription)"; return }
        if let stopReason { stop(reason:stopReason) }
    }
    func stop(reason:String="Stopped") {
        if tapInstalled { engine.inputNode.removeTap(onBus:0); tapInstalled=false }
        engine.stop()
        let pending=processor?.finish() ?? []; processor=nil
        for observer in [interruption,routeChange,mediaReset].compactMap({$0}) { NotificationCenter.default.removeObserver(observer) }
        interruption=nil; routeChange=nil; mediaReset=nil
        try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
        if let store,let id=sessionID {
            store.perform { try store.transact { s in if let i=s.audioSessions.firstIndex(where:{$0.id == id}) {
                s.audioSessions[i].end=store.now; s.audioSessions[i].status=reason
                let saved=Set(s.audioSessions[i].events.map(\.id))
                s.audioSessions[i].events.append(contentsOf:pending.filter{!saved.contains($0.id)})
            } } }
        }
        sessionID=nil; isRunning=false; status=reason; levels=Array(repeating:0,count:40)
    }
    func deleteRecording(_ id:UUID) throws {
        guard let store else { return }
        if sessionID == id { stop(reason:"Stopped before deletion") }
        if let session=store.data.audioSessions.first(where:{$0.id == id}), let name=session.fileName {
            let url=folder.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
        }
        try store.transact { s in if let i=s.audioSessions.firstIndex(where:{$0.id == id}) { s.audioSessions[i].fileName=nil; s.audioSessions[i].events=[]; s.audioSessions[i].status="Recording and events deleted" } }
    }
    func prune() {
        guard let store,!store.isDemo else { return }
        let cutoff=store.now.addingTimeInterval(-Double(store.data.preferences.audioRetentionDays)*86400)
        for item in store.data.audioSessions where item.end != nil && item.start < cutoff && item.fileName != nil {
            // Keep event summaries; only retained raw recordings expire.
            if let name=item.fileName {
                do {
                    let url=folder.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
                    try store.transact { s in if let i=s.audioSessions.firstIndex(where:{$0.id == item.id}) { s.audioSessions[i].fileName=nil } }
                } catch { store.message="Audio cleanup could not finish. \(error.localizedDescription)"; return }
            }
        }
    }
}
/// Audio callback work is serialized here. Only bounded event summaries leave this object.
private final class LevelProcessor:@unchecked Sendable {
    private let lock=NSLock()
    private var file:AVAudioFile?
    private var running=true
    private let sampleRate:Double
    private let start:Date
    private var totalFrames=0
    private var detector=SoundEventDetector()
    private var events:[SoundEvent]=[]
    private var allEvents:[SoundEvent]=[]
    private var eventCount=0
    private var lastFlush:Double=0
    private var lastMeter:Double=0
    private let levelCallback:(Float)->Void
    private let callback:([SoundEvent],String?)->Void
    init(sampleRate:Double,file:AVAudioFile?,start:Date,levelCallback:@escaping(Float)->Void,callback:@escaping([SoundEvent],String?)->Void) {
        self.sampleRate=sampleRate; self.file=file; self.start=start; self.levelCallback=levelCallback; self.callback=callback
    }
    private func append(_ sound:DetectedSound) {
        let event=SoundEvent(date:start.addingTimeInterval(sound.offset),duration:sound.duration,peakDB:sound.peakDB,recordingOffset:sound.offset)
        events.append(event); allEvents.append(event)
        eventCount+=1
    }
    func consume(_ buffer:AVAudioPCMBuffer) {
        lock.lock(); defer{lock.unlock()}
        guard running,let channels=buffer.floatChannelData,buffer.frameLength > 0 else { return }
        let frames=Int(buffer.frameLength)
        if let file {
            do { try file.write(from:buffer) }
            catch { running=false; self.file=nil; callback(events,"Audio write failed; recording stopped"); events=[]; return }
        }
        let offset=Double(totalFrames)/sampleRate
        var rms:Float=0
        for index in 0..<Int(buffer.format.channelCount) {
            var value:Float=0; vDSP_rmsqv(channels[index],1,&value,vDSP_Length(frames)); rms=max(rms,value)
        }
        let db=20*log10(max(rms,0.00000001))
        if let sound=detector.consume(levelDB:db,offset:offset,duration:Double(frames)/sampleRate) { append(sound) }
        totalFrames+=frames
        let elapsed=Double(totalFrames)/sampleRate
        if elapsed-lastMeter >= 0.1 { levelCallback(db); lastMeter=elapsed }
        // Save event batches promptly; meters are never written to the database.
        if elapsed-lastFlush >= 5 {
            lastFlush=elapsed
            var reason:String?
            if let file {
                let resources=try? file.url.resourceValues(forKeys:[.fileSizeKey,.volumeAvailableCapacityForImportantUsageKey])
                if (resources?.fileSize ?? 0) >= 400*1024*1024 { reason="Reached 400 MB recording limit" }
                if let free=resources?.volumeAvailableCapacityForImportantUsage, free < 100*1024*1024 { reason="Storage nearly full; recording stopped" }
            }
            if eventCount >= 6000 { reason="Reached 6,000-event session limit" }
            if let reason { running=false; callback(events,reason) }
            else if !events.isEmpty { callback(events,nil) }
            events=[]
        }
        if running, elapsed >= 12*3600 { running=false; callback(events,"Reached session duration limit"); events=[] }
    }
    func finish()->[SoundEvent] {
        lock.lock(); defer{lock.unlock()}; running=false; file=nil
        if let sound=detector.finish() { append(sound) }
        let result=allEvents; events=[]; allEvents=[]; return result
    }
}
