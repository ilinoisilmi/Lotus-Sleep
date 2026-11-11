import Foundation

/// A practical note to act on after waking. Notification state is device-local on restore.
public struct MorningTask:Codable,Identifiable,Sendable {
    public var id=UUID()
    public var text:String
    public var createdAt:Date
    public var remindAt:Date
    public var completedAt:Date?
    public var notificationScheduled=false
    public var showPreview=false
    public init(text:String,createdAt:Date,remindAt:Date) { self.text=text;self.createdAt=createdAt;self.remindAt=remindAt }
    public func isDue(at now:Date)->Bool { completedAt == nil && remindAt <= now }
    public func validate() throws {
        guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.count <= 1000,
              createdAt.timeIntervalSince1970.isFinite,remindAt.timeIntervalSince1970.isFinite,
              completedAt.map({$0 >= createdAt && $0.timeIntervalSince1970.isFinite}) ?? true,
              completedAt == nil || !notificationScheduled else { throw LumaError.invalid("Add a note of 1–1,000 characters with valid dates. Completed notes cannot have reminders scheduled.") }
    }
}
public enum MorningInbox {
    public static func active(_ tasks:[MorningTask])->[MorningTask] { tasks.filter{$0.completedAt == nil}.sorted{$0.remindAt == $1.remindAt ? $0.createdAt < $1.createdAt : $0.remindAt < $1.remindAt} }
    public static func clearExpired(_ tasks:inout [MorningTask],at now:Date) {
        for i in tasks.indices where tasks[i].remindAt <= now || tasks[i].completedAt != nil { tasks[i].notificationScheduled=false }
    }
    public static func validate(_ tasks:[MorningTask]) throws {
        guard tasks.count <= 1000,Set(tasks.map(\.id)).count == tasks.count,tasks.filter(\.notificationScheduled).count <= 20 else { throw LumaError.invalid("Keep up to 1,000 morning notes and 20 scheduled morning reminders. Delete old notes or turn off a reminder first.") }
        for task in tasks { try task.validate() }
    }
}
