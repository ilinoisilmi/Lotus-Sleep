import Foundation

public enum SleepGoal:String,Codable,CaseIterable,Sendable {
    case fallAsleep="Settle more easily", stayAsleep="Understand wake-ups", consistent="Keep a steadier schedule", energy="Feel more rested"
}
public enum CaffeineSensitivity:String,Codable,CaseIterable,Sendable {
    case unknown="Not sure", usual="No particular sensitivity noticed", sensitive="It affects me strongly"
}
public enum CaffeineContext:String,Codable,CaseIterable,Sendable {
    case unsure="Not sure / prefer not to say", standard="None of these apply", individualAdvice="One or more apply"
}
public struct SleepProfile:Codable,Sendable {
    public var goal=SleepGoal.energy
    public var workSleepMinutes=23*60
    public var workWakeMinutes=7*60
    public var freeSleepMinutes=0
    public var freeWakeMinutes=9*60
    public var workDays=5
    public var freeDayAlarm=false
    public var shiftWork=false
    /// Original reflection questions, not a licensed personality or chronotype instrument.
    public var reflectionScores=[2,2,2,2,2]
    public var caffeineSensitivity=CaffeineSensitivity.unknown
    public var caffeineContext=CaffeineContext.unsure
    public var personalCaffeineCapMG:Double?
    public var updatedAt=Date()
    public init() {}
    public func validate() throws {
        guard [workSleepMinutes,workWakeMinutes,freeSleepMinutes,freeWakeMinutes].allSatisfy({(0..<1440).contains($0)}),
              (0...7).contains(workDays),reflectionScores.count == 5,reflectionScores.allSatisfy({(0...4).contains($0)}) else { throw LumaError.invalid("Check the profile times and answers.") }
        for duration in [BodyClockEstimate.duration(from:workSleepMinutes,to:workWakeMinutes),BodyClockEstimate.duration(from:freeSleepMinutes,to:freeWakeMinutes)] {
            guard (60...960).contains(duration) else { throw LumaError.invalid("Describe a main sleep window between 1 and 16 hours. Use the diary for split sleep.") }
        }
        if let cap=personalCaffeineCapMG { guard cap.isFinite,(0...400).contains(cap) else { throw LumaError.invalid("A personal caffeine cap must be between 0 and 400 mg. This is a tracking preference, not a safe-dose calculation.") } }
    }
    public var windDownStyle:String {
        if reflectionScores[0] >= 3 { return "A busy mind at bedtime" }
        if reflectionScores[1] >= 3 { return "Aware of small sounds" }
        if reflectionScores[2] >= 3 { return "Comfort in a routine" }
        return "An adaptable wind-down"
    }
    public var suggestion:String {
        let quiet=reflectionScores[3] >= 3
        if reflectionScores[0] >= 3 { return "Try writing tomorrow’s tasks down before your wind-down. Choose a quiet, familiar activity afterward." }
        if reflectionScores[1] >= 3 { return quiet ? "Try reducing room noise first. Silence is a valid preference; background audio is optional." : "Try a quiet, steady sound at a comfortable volume and see whether you prefer it to silence." }
        if reflectionScores[2] >= 3 { return "Keep a familiar order for your evening: prepare for tomorrow, lower the lights, then do something calm." }
        return "Choose a simple wind-down you enjoy. Your own comfort matters more than a quiz label."
    }
}
public struct BodyClockEstimate:Sendable {
    public var freeMidpointMinutes:Double
    public var adjustedMidpointMinutes:Double?
    public var scheduleShiftMinutes:Double?
    public var tendency:String
    public var explanation:String
    public static func duration(from:Int,to:Int)->Int { (to-from+1440)%1440 }
    private static func normalized(_ value:Double)->Double { (value.truncatingRemainder(dividingBy:1440)+1440).truncatingRemainder(dividingBy:1440) }
    public static func estimate(_ p:SleepProfile)->BodyClockEstimate {
        let work=Double(duration(from:p.workSleepMinutes,to:p.workWakeMinutes))
        let free=Double(duration(from:p.freeSleepMinutes,to:p.freeWakeMinutes))
        let mid=normalized(Double(p.freeSleepMinutes)+free/2)
        guard !p.shiftWork,!p.freeDayAlarm,p.workDays < 7 else {
            return BodyClockEstimate(freeMidpointMinutes:mid,adjustedMidpointMinutes:nil,scheduleShiftMinutes:nil,tendency:"Schedule estimate only",explanation:"An alarm on free days, no free days, or rotating/night shifts can distort this estimate. Your reported midpoint is shown without assigning a chronotype.")
        }
        let weighted=(work*Double(p.workDays)+free*Double(7-p.workDays))/7
        let adjusted=normalized(mid-max(0,free-weighted)/2)
        let workMid=normalized(Double(p.workSleepMinutes)+work/2)
        let distance=abs(mid-workMid)
        // Transparent product heuristic; these cutoffs are not a validated clinical scale.
        let label=adjusted < 180 ? "Earlier-leaning schedule" : adjusted < 300 ? "Middle-leaning schedule" : "Later-leaning schedule"
        return BodyClockEstimate(freeMidpointMinutes:mid,adjustedMidpointMinutes:adjusted,scheduleShiftMinutes:p.workDays == 0 ? nil : min(distance,1440-distance),tendency:label,explanation:"A rough tendency from reported sleep timing, adjusted for extra free-day sleep. It does not measure melatonin, your internal body clock, or your exact sleep need.")
    }
}
public struct CaffeineEntry:Codable,Identifiable,Sendable {
    public var id=UUID()
    public var date:Date
    public var milligrams:Double
    public var label:String
    public init(date:Date,milligrams:Double,label:String) { self.date=date;self.milligrams=milligrams;self.label=label }
    public func validate() throws {
        guard milligrams.isFinite,milligrams > 0,milligrams <= 2000,label.count <= 100 else { throw LumaError.invalid("Enter caffeine in mg (more than 0, up to 2,000) and a short label. The entry limit is not a safe amount.") }
    }
}
public enum CaffeineAdvice {
    public static func isAdult(_ p:Preferences)->Bool { ["18–60","61–64","65+"].contains(p.ageBand) }
    public static func cutoffHours(_ profile:SleepProfile?)->Int { profile?.caffeineSensitivity == .usual ? 8 : 10 }
    public static func cutoff(bedtime:Date,profile:SleepProfile?)->Date { bedtime.addingTimeInterval(-Double(cutoffHours(profile))*3600) }
    public static func dailyTotal(_ entries:[CaffeineEntry],on date:Date,zoneID:String)->Double {
        let calendar=SleepCalendar.calendar(zoneID:zoneID)
        guard let day=calendar.dateInterval(of:.day,for:date) else { return 0 }
        return entries.filter{$0.date >= day.start && $0.date < day.end}.reduce(0){$0+$1.milligrams}
    }
    public static func message(preferences:Preferences,profile:SleepProfile?,total:Double)->String {
        guard isAdult(preferences) else { return "For under-18s, the American Academy of Pediatrics advises avoiding caffeine. Lotus does not recommend a caffeine dose or a time to take it. Logging is for awareness." }
        guard profile?.caffeineContext == .standard else { return "Lotus cannot calculate a safe dose from a questionnaire. Pregnancy, breastfeeding, medicines, conditions or uncertainty need individual advice from a clinician. You can still track intake and set a bedtime cutoff." }
        if total >= 400 { return "You have reached or exceeded the FDA’s general 400 mg/day adult reference. That reference is not a personal safe limit or a target; some people need much less." }
        if let cap=profile?.personalCaffeineCapMG,total > cap { return "You have passed your chosen daily cap. This cap is a tracking preference, not a medical safety limit." }
        return "The FDA cites 400 mg/day for most adults as an amount not generally associated with negative effects, but sensitivity varies. It is not a target or a personalized recommendation. Less may suit you better."
    }
}
public struct ReminderOptions:Codable,Sendable {
    public var windDown=true
    public var bedtime=true
    public var caffeine=false
    public init() {}
}
public struct PlannedReminder:Identifiable,Sendable {
    public var id:String
    public var date:Date
    public var title:String
    public var body:String
}
public enum ReminderPlanner {
    public static func fingerprint(preferences p:Preferences,profile:SleepProfile?)->String {
        let o=p.reminderOptions ?? ReminderOptions()
        return "\(p.weekdayWakeMinutes)|\(p.weekendWakeMinutes)|\(p.targetHours)|\(p.settlingMinutes)|\(p.windDownMinutes)|\(p.reportingTimeZoneID)|\(o.windDown)|\(o.bedtime)|\(o.caffeine)|\(CaffeineAdvice.cutoffHours(profile))|\(CaffeineAdvice.isAdult(p))"
    }
    public static func weekly(preferences p:Preferences,profile:SleepProfile?,after date:Date)->[PlannedReminder] {
        let cal=SleepCalendar.calendar(zoneID:p.reportingTimeZoneID),options=p.reminderOptions ?? ReminderOptions()
        var result:[PlannedReminder]=[]
        for weekday in 1...7 {
            let minutes=(weekday == 1 || weekday == 7) ? p.weekendWakeMinutes : p.weekdayWakeMinutes
            var match=DateComponents(); match.weekday=weekday;match.hour=minutes/60;match.minute=minutes%60
            guard let wake=cal.nextDate(after:date,matching:match,matchingPolicy:.nextTime,repeatedTimePolicy:.first) else { continue }
            let plan=SleepPlanner.plan(wake:wake,preferences:p)
            if options.windDown { result.append(PlannedReminder(id:"luma.wind.\(weekday)",date:plan.windDown,title:"Lotus · time to unwind",body:"Make a little room for your evening routine.")) }
            if options.bedtime { result.append(PlannedReminder(id:"luma.bed.\(weekday)",date:plan.bedtime,title:"Lotus · bedtime",body:"Your planned time for rest is here.")) }
            if options.caffeine { result.append(PlannedReminder(id:"luma.caffeine.\(weekday)",date:CaffeineAdvice.cutoff(bedtime:plan.bedtime,profile:profile),title:"Lotus · caffeine reminder",body:CaffeineAdvice.isAdult(p) ? "Your bedtime-based caffeine cutoff is here. Consider a caffeine-free drink." : "Choose a caffeine-free drink. Avoiding caffeine is the recommended choice for teens.")) }
        }
        return result
    }
}
public struct CustomSleepSound:Codable,Identifiable,Sendable {
    public var id:UUID
    public var name:String
    public var fileName:String
    public var duration:Double
    public init(id:UUID,name:String,fileName:String,duration:Double) { self.id=id;self.name=name;self.fileName=fileName;self.duration=duration }
    public func validate() throws {
        guard !name.isEmpty,name.count <= 100,duration.isFinite,(1...7200).contains(duration),
              ["mp3","m4a","wav"].contains(URL(fileURLWithPath:fileName).pathExtension.lowercased()),
              fileName == id.uuidString+"."+URL(fileURLWithPath:fileName).pathExtension,
              !fileName.contains("/"),!fileName.contains("\\") else { throw LumaError.invalid("Invalid custom sound metadata.") }
    }
}
