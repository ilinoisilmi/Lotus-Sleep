import Foundation
import UserNotifications
import Combine

@MainActor protocol ReminderScheduling {
    func install(preferences:Preferences,profile:SleepProfile?) async throws
    func cancelAll()
}
struct NotificationPreview:Identifiable {
    let id:String
    let title:String
    let nextDate:Date?
}
@MainActor final class ReminderService:NSObject,ObservableObject,ReminderScheduling,UNUserNotificationCenterDelegate {
    @Published private(set) var permission="Checking notification access…"
    @Published private(set) var scheduled:[NotificationPreview]=[]
    @Published private(set) var canDeliver=false
    private let center=UNUserNotificationCenter.current()
    private var isInstalling=false
    private var generation=0
    static var weeklyIDs:[String] { (1...7).flatMap{["luma.wind.\($0)","luma.bed.\($0)","luma.caffeine.\($0)"]} }
    override init() { super.init(); center.delegate=self }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification) async -> UNNotificationPresentationOptions { [.banner,.sound,.list] }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse) async {
        if response.notification.request.identifier.hasPrefix("luma.morning.") {
            await MainActor.run {
                let store=AppStore.shared
                if store.isDemo { store.toggleDemo() }
                if !store.isDemo { store.openMorningInbox=true }
            }
        }
    }
    func refresh() async {
        let token=generation
        let settings=await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:permission="Allowed in iOS"
        case .provisional:permission="Quiet delivery allowed"
        case .ephemeral:permission="Temporary access allowed"
        case .denied:permission="Off in iOS Settings"
        case .notDetermined:permission="Not requested yet"
        @unknown default:permission="Check iOS Settings"
        }
        canDeliver=[UNAuthorizationStatus.authorized,.provisional,.ephemeral].contains(settings.authorizationStatus)
        let requests=await center.pendingNotificationRequests()
        guard token == generation else { return }
        scheduled=requests.filter{$0.identifier.hasPrefix("luma.")}.map { NotificationPreview(id:$0.identifier,title:$0.content.title,nextDate:($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()) }.sorted{($0.nextDate ?? .distantFuture)<($1.nextDate ?? .distantFuture)}
    }
    private func authorize() async throws {
        guard try await center.requestAuthorization(options:[.alert,.sound]) else { await refresh(); throw LumaError.unavailable("Notifications are off. Open iPhone Settings → Notifications → Lotus Sleep to allow them.") }
    }
    private func begin() throws->Int {
        guard !isInstalling else { throw LumaError.unavailable("Notification scheduling is already in progress.") }
        isInstalling=true;return generation
    }
    private func add(_ request:UNNotificationRequest,generation token:Int) async throws {
        guard token == generation else { throw LumaError.unavailable("Notification scheduling was cancelled.") }
        try await center.add(request)
        guard token == generation else {
            center.removePendingNotificationRequests(withIdentifiers:[request.identifier])
            throw LumaError.unavailable("Notification scheduling was cancelled.")
        }
    }
    func install(preferences p:Preferences,profile:SleepProfile?=nil) async throws {
        let token=try begin();defer { isInstalling=false }
        let plans=ReminderPlanner.weekly(preferences:p,profile:profile,after:Date())
        if plans.isEmpty { center.removePendingNotificationRequests(withIdentifiers:Self.weeklyIDs);await refresh();return }
        try await authorize()
        guard token == generation else { throw LumaError.unavailable("Notification scheduling was cancelled.") }
        let calendar=SleepCalendar.calendar(zoneID:p.reportingTimeZoneID)
        center.removePendingNotificationRequests(withIdentifiers:Self.weeklyIDs)
        do {
            for item in plans {
                var match=calendar.dateComponents([.weekday,.hour,.minute],from:item.date);match.timeZone=calendar.timeZone
                let content=UNMutableNotificationContent();content.title=item.title;content.body=item.body;content.sound = .default
                try await add(UNNotificationRequest(identifier:item.id,content:content,trigger:UNCalendarNotificationTrigger(dateMatching:match,repeats:true)),generation:token)
            }
        } catch { center.removePendingNotificationRequests(withIdentifiers:Self.weeklyIDs);await refresh();throw error }
        await refresh()
        guard token == generation else { throw LumaError.unavailable("Notification scheduling was cancelled.") }
    }
    func test() async throws {
        let token=try begin();defer { isInstalling=false }
        try await authorize()
        let content=UNMutableNotificationContent();content.title="Lotus Sleep · test";content.body="Your test notification arrived. Bedtime, wind-down and caffeine reminders use the same permission.";content.sound = .default
        try await add(UNNotificationRequest(identifier:"luma.test",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:5,repeats:false)),generation:token)
        await refresh()
    }
    func habit(at date:Date,title:String) async throws {
        let token=try begin();defer { isInstalling=false }
        let text=title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard date.timeIntervalSinceNow >= 1,!text.isEmpty,text.count <= 200 else { throw LumaError.invalid("Choose a future time and a reminder of 1–200 characters.") }
        try await authorize()
        let content=UNMutableNotificationContent();content.title="Lotus · your reminder";content.body=text;content.sound = .default
        try await add(UNNotificationRequest(identifier:"luma.habit",content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:max(1,date.timeIntervalSinceNow),repeats:false)),generation:token)
        await refresh()
    }
    func morning(_ task:MorningTask) async throws {
        let token=try begin();defer { isInstalling=false }
        try task.validate()
        guard task.remindAt.timeIntervalSinceNow > 0,task.completedAt == nil else { throw LumaError.invalid("Choose a future reminder for an unfinished note.") }
        try await authorize()
        guard task.remindAt.timeIntervalSinceNow > 0 else { throw LumaError.invalid("The reminder time passed while choosing notification access. Choose a new time.") }
        let content=UNMutableNotificationContent();content.title="Lotus · morning inbox"
        content.body=task.showPreview ? task.text : "You left yourself a note. Open your morning inbox."
        content.sound = .default
        try await add(UNNotificationRequest(identifier:"luma.morning."+task.id.uuidString,content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:max(1,task.remindAt.timeIntervalSinceNow),repeats:false)),generation:token)
        await refresh()
    }
    func cancelMorning(_ id:UUID) {
        let identifier="luma.morning."+id.uuidString
        center.removePendingNotificationRequests(withIdentifiers:[identifier])
        center.removeDeliveredNotifications(withIdentifiers:[identifier])
        scheduled.removeAll{$0.id == identifier}
    }
    func cancelAll() {
        generation+=1
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications();scheduled=[]
    }
}
