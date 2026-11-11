import Foundation

public struct DetectedSound: Equatable, Sendable {
    public var offset: TimeInterval
    public var duration: TimeInterval
    public var peakDB: Float
}

/// Loudness events, not speech/snore/sleep classification. Offsets follow recorded audio frames.
public struct SoundEventDetector: Sendable {
    public private(set) var noiseFloor: Float = -60
    public private(set) var calibratedSeconds: Double = 0
    public var threshold: Float { min(-18,max(-50,noiseFloor+10)) }
    private var start: Double?
    private var lastLoudEnd: Double = 0
    private var peak: Float = -160
    public init() {}
    public mutating func consume(levelDB: Float, offset: Double, duration: Double) -> DetectedSound? {
        guard levelDB.isFinite, offset.isFinite, duration.isFinite, offset >= 0, duration > 0 else { return nil }
        if calibratedSeconds < 5 {
            let total=calibratedSeconds+duration
            noiseFloor=Float((Double(noiseFloor)*calibratedSeconds+Double(levelDB)*duration)/total)
            calibratedSeconds=total
            return nil
        }
        let end=offset+duration
        if levelDB > threshold {
            if start == nil { start=offset }
            lastLoudEnd=end; peak=max(peak,levelDB)
            if let start, end-start >= 30 { return finish() }
        } else {
            // Quiet background follows slowly; a long sound never raises the threshold itself.
            noiseFloor += (levelDB-noiseFloor)*Float(min(0.02,duration/30))
            if start != nil, end-lastLoudEnd >= 0.8 { return finish() }
        }
        return nil
    }
    public mutating func finish() -> DetectedSound? {
        defer { start=nil; peak = -160 }
        guard let start, lastLoudEnd-start >= 0.3 else { return nil }
        return DetectedSound(offset:start,duration:lastLoudEnd-start,peakDB:peak)
    }
}
