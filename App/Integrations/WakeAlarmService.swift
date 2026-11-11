import SwiftUI
import Combine
#if canImport(AlarmKit)
import AlarmKit
#endif
@MainActor final class WakeAlarmService:ObservableObject {
    @Published var status="No wake alarm scheduled"
    @Published var scheduledDate:Date?
    private let defaults=UserDefaults.standard
    // Stable ID: cancellation and replacement survive process exits.
    private let id=UUID(uuidString:"5F3E9A5D-04B8-48B9-9DFD-34D90AC5D8A2")!
    var supported:Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0,*) { return true }
        #endif
        return false
    }
    func schedule(at date:Date) async throws {
        guard date>Date() else { throw LumaError.invalid("Choose a future wake time.") }
        #if canImport(AlarmKit)
        if #available(iOS 26.0,*) {
            let manager=AlarmManager.shared
            guard try await manager.requestAuthorization() == .authorized else { throw LumaError.unavailable("Alarm access is off. Enable it in Settings or set an alarm in Apple's Clock app.") }
            let alert=AlarmPresentation.Alert(title:"Time to wake",stopButton:AlarmButton(text:"Stop",textColor:.white,systemImageName:"stop.circle"))
            let attributes=AlarmAttributes(presentation:AlarmPresentation(alert:alert),metadata:LumaAlarmMetadata(),tintColor:Color.purple)
            // Alert-only alarm: no countdown presentation or Live Activity is needed.
            let config=AlarmManager.AlarmConfiguration<LumaAlarmMetadata>.alarm(schedule:.fixed(date),attributes:attributes)
            _ = try await manager.schedule(id:id,configuration:config)
            defaults.set(date.timeIntervalSince1970,forKey:"luma.wakeAlarmDate")
            scheduledDate=date; status="Wake alarm scheduled"
            return
        }
        #endif
        throw LumaError.unavailable("System wake alarms need iOS 26 or later and an SDK with AlarmKit. On this version, use Apple's Clock app. Lotus's reminders are ordinary notifications, not reliable wake alarms.")
    }
    func cancel() async throws {
        #if canImport(AlarmKit)
        if #available(iOS 26.0,*) {
            if try AlarmManager.shared.alarms.contains(where:{$0.id == id}) { try AlarmManager.shared.cancel(id:id) }
        }
        #endif
        defaults.removeObject(forKey:"luma.wakeAlarmDate"); scheduledDate=nil; status="No wake alarm scheduled"
    }
    func refresh() async {
        #if canImport(AlarmKit)
        if #available(iOS 26.0,*) {
            do {
                let existing=try AlarmManager.shared.alarms.contains{$0.id == id}
                if existing, let stamp=defaults.object(forKey:"luma.wakeAlarmDate") as? Double { scheduledDate=Date(timeIntervalSince1970:stamp); status="Wake alarm registered with iOS" }
                else { scheduledDate=nil; status="No wake alarm scheduled"; defaults.removeObject(forKey:"luma.wakeAlarmDate") }
            } catch { status="Unable to verify alarm. Check iPhone alarm settings."; scheduledDate=nil }
        }
        #endif
    }
}
#if canImport(AlarmKit)
@available(iOS 26.0,*) struct LumaAlarmMetadata:AlarmMetadata {}
#endif
