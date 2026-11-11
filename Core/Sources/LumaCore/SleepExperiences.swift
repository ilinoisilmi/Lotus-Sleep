import Foundation

public enum SleepSoundSource:Codable,Hashable,Sendable {
    case builtIn(String),custom(UUID)
    public static let builtInIDs=["white","pink","brown","rain","ocean","fan"]
    public var key:String { switch self {case .builtIn(let name):return "builtin:"+name;case .custom(let id):return "custom:"+id.uuidString} }
    public func validate() throws { if case .builtIn(let name)=self,!Self.builtInIDs.contains(name) { throw LumaError.invalid("Unknown built-in sound.") } }
}
public struct SoundLayer:Codable,Identifiable,Equatable,Sendable {
    public var source:SleepSoundSource
    public var volume:Double
    public var id:String { source.key }
    public init(source:SleepSoundSource,volume:Double=0.6) { self.source=source;self.volume=volume }
}
public struct SoundBlend:Codable,Identifiable,Sendable {
    public var id=UUID()
    public var name:String
    public var layers:[SoundLayer]
    public var timerMinutes=30
    public var loop=true
    public init(name:String,layers:[SoundLayer]) { self.name=name;self.layers=layers }
    public func validate() throws {
        guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,name.count <= 80,(1...3).contains(layers.count),
              Set(layers.map(\.source)).count == layers.count,[0,15,30,45,60,90,120].contains(timerMinutes),
              layers.allSatisfy({$0.volume.isFinite && (0...1).contains($0.volume)}),layers.contains(where:{$0.volume > 0}) else { throw LumaError.invalid("Name your mix, choose 1–3 different sounds and give at least one sound some volume.") }
        for layer in layers { try layer.source.validate() }
    }
    /// Keep the sum of layer gains at or below the master volume.
    public static func gains(layers:[SoundLayer],master:Double,fade:Double)->[Double] {
        let total=max(1,layers.reduce(0){$0+max(0,$1.volume)})
        return layers.map{min(1,max(0,$0.volume))/total*min(1,max(0,master))*min(1,max(0,fade))}
    }
}
public enum ExperimentCondition:String,Codable,CaseIterable,Sendable { case a="A",b="B",skipped="Neither / skipped" }
public struct ExperimentNight:Codable,Identifiable,Sendable {
    public var dayIndex:Int
    public var condition:ExperimentCondition
    public var rested:Int?
    public var notes:String
    public var id:Int { dayIndex }
    public init(dayIndex:Int,condition:ExperimentCondition,rested:Int?,notes:String="") { self.dayIndex=dayIndex;self.condition=condition;self.rested=rested;self.notes=notes }
}
public struct SleepExperiment:Codable,Identifiable,Sendable {
    public var id=UUID()
    public var title:String
    public var optionA:String
    public var optionB:String
    public var startDay:Date
    public var timeZoneID:String
    public var boundaryHour:Int
    public var nights:[ExperimentNight]=[]
    public var archived=false
    public init(title:String,optionA:String,optionB:String,startDay:Date,timeZoneID:String,boundaryHour:Int) {
        self.title=title;self.optionA=optionA;self.optionB=optionB;self.startDay=SleepCalendar.calendar(zoneID:timeZoneID).startOfDay(for:startDay);self.timeZoneID=timeZoneID;self.boundaryHour=boundaryHour
    }
    public func day(_ index:Int)->Date { SleepCalendar.calendar(zoneID:timeZoneID).date(byAdding:.day,value:index,to:startDay)! }
    public func availableIndex(at now:Date)->Int { min(13,(SleepCalendar.calendar(zoneID:timeZoneID).dateComponents([.day],from:startDay,to:SleepCalendar.calendar(zoneID:timeZoneID).startOfDay(for:now)).day ?? -1)) }
    public func planned(_ index:Int)->ExperimentCondition { [ExperimentCondition.a,.b,.b,.a,.a,.b,.a,.b,.a,.a,.b,.b,.a,.b][max(0,min(13,index))] }
    public func validate() throws {
        guard [title,optionA,optionB].allSatisfy({!$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.count <= 120}),
              optionA.trimmingCharacters(in:.whitespacesAndNewlines).lowercased() != optionB.trimmingCharacters(in:.whitespacesAndNewlines).lowercased(),
              TimeZone(identifier:timeZoneID) != nil,startDay == SleepCalendar.calendar(zoneID:timeZoneID).startOfDay(for:startDay),(0...23).contains(boundaryHour),nights.count <= 14,Set(nights.map(\.dayIndex)).count == nights.count else { throw LumaError.invalid("Give the experiment two different options and a valid schedule.") }
        for night in nights {
            guard (0..<14).contains(night.dayIndex),night.notes.count <= 1000,
                  night.condition == .skipped ? night.rested == nil : (night.rested.map{(1...5).contains($0)} ?? false) else { throw LumaError.invalid("Rate how rested you feel from 1–5, or mark the night skipped.") }
        }
    }
    public mutating func log(_ night:ExperimentNight,at now:Date) throws {
        guard !archived,night.dayIndex <= availableIndex(at:now) else { throw LumaError.invalid("Log a morning that has arrived in this experiment’s timezone. Reopen an archived experiment before editing.") }
        var copy=self;copy.nights.removeAll{$0.dayIndex == night.dayIndex};copy.nights.append(night);try copy.validate();self=copy
    }
}
public struct ExperimentGroupSummary:Sendable {
    public var count:Int
    public var meanRested:Double?
    public var sleepCount:Int
    public var meanSleepHours:Double?
}
public struct ExperimentComparison:Sendable {
    public var a:ExperimentGroupSummary
    public var b:ExperimentGroupSummary
    public var skipped:Int
    public var ready:Bool { a.count >= 3 && b.count >= 3 }
    public static func calculate(_ experiment:SleepExperiment,snapshot:Snapshot,now:Date)->ExperimentComparison {
        let usable=experiment.nights.filter{$0.dayIndex <= experiment.availableIndex(at:now)}
        var preferences=snapshot.preferences;preferences.reportingTimeZoneID=experiment.timeZoneID;preferences.boundaryHour=experiment.boundaryHour
        let records=snapshot.effectiveRecords.filter{$0.end <= now}
        func group(_ condition:ExperimentCondition)->ExperimentGroupSummary {
            let nights=usable.filter{$0.condition == condition && $0.rested != nil}
            let sleep=nights.compactMap{SleepCalendar.days(records:records,endingOn:experiment.day($0.dayIndex),count:1,preferences:preferences).first?.hours}
            return ExperimentGroupSummary(count:nights.count,meanRested:nights.isEmpty ? nil : Double(nights.compactMap(\.rested).reduce(0,+))/Double(nights.count),sleepCount:sleep.count,meanSleepHours:sleep.isEmpty ? nil : sleep.reduce(0,+)/Double(sleep.count))
        }
        return ExperimentComparison(a:group(.a),b:group(.b),skipped:usable.filter{$0.condition == .skipped}.count)
    }
}
public enum RewindKind:String,CaseIterable,Sendable { case sleep="Sleep evidence",inBed="Time in bed",wake="Logged wake-up",sound="Sound",unknown="Unknown" }
public struct RewindItem:Identifiable,Sendable {
    public var id:String
    public var start:Date
    public var end:Date
    public var kind:RewindKind
    public var title:String
    public var detail:String
    public var sessionID:UUID?
    public var eventID:UUID?
}
public enum NightRewind {
    public static func items(snapshot:Snapshot,window:DateInterval,now:Date)->[RewindItem] {
        let end=min(window.end,now)
        guard window.start < end else { return [] }
        let bounds=DateInterval(start:window.start,end:end)
        let sleep=SleepReconciler.resolve(snapshot.effectiveRecords,priority:snapshot.preferences.sourcePriority,within:bounds)
        var result:[RewindItem]=[]
        for segment in sleep.segments {
            result.append(RewindItem(id:"sleep:"+segment.id,start:segment.start,end:segment.end,kind:.sleep,title:segment.record.stage.label,detail:segment.record.sourceName+" · "+segment.record.quality.rawValue+(segment.hasConflict ? " · conflicting sources" : "")))
        }
        for (i,interval) in sleep.inBed.enumerated() {
            result.append(RewindItem(id:"bed:\(i)",start:interval.start,end:interval.end,kind:.inBed,title:"Recorded time in bed",detail:"Time in bed does not prove sleep."))
        }
        var cursor=bounds.start
        for interval in SleepReconciler.union(sleep.segments.map{DateInterval(start:$0.start,end:$0.end)}) {
            if interval.start > cursor { result.append(RewindItem(id:"unknown:\(cursor.timeIntervalSince1970)",start:cursor,end:interval.start,kind:.unknown,title:"No sleep-state evidence",detail:"No sleep or wake state is inferred here.")) }
            cursor=max(cursor,interval.end)
        }
        if cursor < end { result.append(RewindItem(id:"unknown:\(cursor.timeIntervalSince1970)",start:cursor,end:end,kind:.unknown,title:"No sleep-state evidence",detail:"A quiet phone or room does not fill this gap.")) }
        for wake in snapshot.disturbances where wake.start < end && (wake.end ?? end) > window.start {
            result.append(RewindItem(id:"wake:"+wake.id.uuidString,start:max(window.start,wake.start),end:max(max(window.start,wake.start),min(end,wake.end ?? wake.start)),kind:.wake,title:wake.reason.title,detail:(wake.end == nil ? "End not recorded. " : "Returned to rest, not detected sleep onset. ")+wake.notes))
        }
        for session in snapshot.audioSessions {
            for event in session.events where event.date < end && event.date.addingTimeInterval(event.duration) > window.start {
                result.append(RewindItem(id:"sound:"+session.id.uuidString+":"+event.id.uuidString,start:max(window.start,event.date),end:min(end,event.date.addingTimeInterval(event.duration)),kind:.sound,title:"Sound event",detail:"\(String(format:"%.1f",event.duration))s · source not identified",sessionID:session.id,eventID:event.id))
            }
        }
        return result.sorted{$0.start == $1.start ? $0.id < $1.id : $0.start < $1.start}
    }
}
