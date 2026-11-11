import SwiftUI
import WidgetKit
struct PlanEntry:TimelineEntry { let date:Date; var enabled:Bool; var windDown:Date? }
struct PlanProvider:TimelineProvider {
    func placeholder(in context:Context)->PlanEntry { PlanEntry(date:Date(),enabled:false,windDown:nil) }
    func getSnapshot(in context:Context,completion:@escaping(PlanEntry)->Void) { completion(entry()) }
    func getTimeline(in context:Context,completion:@escaping(Timeline<PlanEntry>)->Void) { completion(Timeline(entries:[entry()],policy:.after(Date().addingTimeInterval(3600)))) }
    private func entry()->PlanEntry {
        guard let group=Bundle.main.object(forInfoDictionaryKey:"LumaAppGroup") as? String,let d=UserDefaults(suiteName:group),d.bool(forKey:"enabled") else{return PlanEntry(date:Date(),enabled:false,windDown:nil)}
        let time=d.double(forKey:"windDown"),date=time>0 ? Date(timeIntervalSince1970:time) : nil
        return PlanEntry(date:Date(),enabled:true,windDown:date)
    }
}
struct PlanWidgetView:View {
    let entry:PlanEntry
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Label("LUMA",systemImage:"moon.stars").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.purple)
            if entry.enabled,let time=entry.windDown,time>Date().addingTimeInterval(-3600) {
                Text(time,style:.time).font(.system(.title,design:.rounded,weight:.semibold))
                Text("Start winding down").font(.caption)
            } else {
                Text("Make room\nfor rest.").font(.system(.title3,design:.rounded,weight:.medium))
                Text(entry.enabled ? "Open Lotus to update your plan" : "Enable your plan in Settings").font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth:.infinity,alignment:.leading).containerBackground(for:.widget){Color.purple.opacity(0.08)}.widgetURL(URL(string:"lumasleep://today"))
    }
}
@main struct LumaPlanWidget:Widget {
    let kind="LumaPlan"
    var body:some WidgetConfiguration { StaticConfiguration(kind:kind,provider:PlanProvider()){PlanWidgetView(entry:$0)}.configurationDisplayName("Tonight's plan").description("Your wind-down time. Enable sharing in Lotus Settings.").supportedFamilies([.systemSmall,.systemMedium]) }
}
