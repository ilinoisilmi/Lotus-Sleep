import SwiftUI
import Charts
import UIKit

enum Luma {
    static let lavender=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.75,green:0.70,blue:1,alpha:1) : UIColor(red:0.37,green:0.28,blue:0.69,alpha:1) })
    static let actionText=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.04,green:0.05,blue:0.10,alpha:1) : .white })
    static let blue=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.52,green:0.72,blue:0.97,alpha:1) : UIColor(red:0.12,green:0.37,blue:0.64,alpha:1) })
    static let warm=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.98,green:0.80,blue:0.52,alpha:1) : UIColor(red:0.55,green:0.31,blue:0.08,alpha:1) })
    static let background=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.035,green:0.047,blue:0.095,alpha:1) : UIColor(red:0.97,green:0.965,blue:0.99,alpha:1) })
    static let surface=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.075,green:0.09,blue:0.155,alpha:1) : .white })
    static func day(_ date:Date,zoneID:String,short:Bool=false)->String {
        let formatter=DateFormatter(); formatter.timeZone=TimeZone(identifier:zoneID) ?? .current
        if short { formatter.dateFormat="d MMM" } else { formatter.dateStyle = .full }
        return formatter.string(from:date)
    }
    static func duration(_ seconds:Double) -> String { let minutes=Int(max(0,seconds)/60); return "\(minutes/60)h \(minutes%60)m" }
    static func stage(_ s:SleepStage) -> Color { switch s { case .inBed:return .gray; case .awake:return warm; case .deep:return .indigo; case .core:return blue; case .rem:return lavender; case .asleep:return lavender } }
    static func haptic() { UIImpactFeedbackGenerator(style:.soft).impactOccurred() }
}
struct LumaPage<Content:View>: View {
    var content: Content
    init(@ViewBuilder content:()->Content) { self.content=content() }
    var body: some View { ScrollView { VStack(alignment:.leading,spacing:26) { content }.padding(.horizontal,22).padding(.top,16).padding(.bottom,32).frame(maxWidth:680) }.frame(maxWidth:.infinity).background(Luma.background) }
}
struct Surface<Content:View>: View {
    var content: Content
    init(@ViewBuilder content:()->Content) { self.content=content() }
    var body: some View { VStack(alignment:.leading,spacing:14) { content }.frame(maxWidth:.infinity,alignment:.leading).padding(20).background(Luma.surface,in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).strokeBorder(.primary.opacity(0.06))) }
}
struct Eyebrow: View { let text:String; var body:some View { Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary) } }
struct SectionTitle: View { let title:String; var subtitle:String?; var body:some View { VStack(alignment:.leading,spacing:6) { Text(title).font(.title2.weight(.semibold)); if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) } } } }
struct PrimaryButton: View {
    let title:String; var symbol:String="arrow.right"; var action:()->Void
    var body:some View { Button { Luma.haptic(); action() } label: { Label(title,systemImage:symbol).foregroundStyle(Luma.actionText).font(.headline).frame(maxWidth:.infinity).padding(.vertical,16) }.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius:18)) }
}
struct EmptyPanel: View {
    let symbol:String; let title:String; let text:String
    var body:some View { VStack(alignment:.leading,spacing:14) { Image(systemName:symbol).font(.system(size:30,weight:.light)).foregroundStyle(Luma.lavender).accessibilityHidden(true); Text(title).font(.title3.weight(.semibold)); Text(text).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,10) }
}
struct SleepBarChart: View {
    let days:[SleepDay]; let target:Double; var zoneID:String=TimeZone.current.identifier
    var ratings:[Date:NightRating]=[:]
    @State private var selection:Date?
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            Chart {
                ForEach(days) { day in
                    if let hours=day.hours { BarMark(x:.value("Sleep day",day.date),y:.value("Hours",hours),width:.fixed(days.count>14 ? 5 : days.count>7 ? 10 : 20)).foregroundStyle((ratings[day.date]?.tint ?? Luma.lavender).gradient).cornerRadius(4) }
                    else { PointMark(x:.value("Sleep day",day.date),y:.value("Unknown",0)).symbol(.cross).foregroundStyle(.secondary) }
                }
                RuleMark(y:.value("Target",target)).lineStyle(StrokeStyle(lineWidth:1,dash:[4])).foregroundStyle(Luma.warm)
                if let selection { RuleMark(x:.value("Selected",selection)).foregroundStyle(.secondary) }
            }
            .chartXAxis {
                AxisMarks(values:days.enumerated().filter { $0.offset % (days.count>14 ? 7 : days.count>7 ? 3 : 1) == 0 }.map { $0.element.date }) { axis in
                    AxisGridLine()
                    if let date=axis.as(Date.self) { AxisValueLabel { Text(Luma.day(date,zoneID:zoneID,short:true)) } }
                }
            }
            .chartXSelection(value:$selection).chartYScale(domain:0...max(12,(days.compactMap(\.hours).max() ?? 0)+1))
            .frame(height:170)
            .accessibilityLabel("Sleep hours by day. Crosses mark unknown days. Target \(target.formatted()) hours.")
            if let selection, let day=days.min(by:{abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))}) {
                Text("\(Luma.day(day.date,zoneID:zoneID)): \(day.hours.map { Luma.duration($0*3600) } ?? "No recorded sleep")").font(.caption)
            }
        }
    }
}
struct StageTimeline: View {
    let sleep:ResolvedSleep
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Chart(sleep.segments) { s in
                RectangleMark(xStart:.value("Start",s.start),xEnd:.value("End",s.end),y:.value("Stage",s.record.stage.label),height:.ratio(0.7)).foregroundStyle(Luma.stage(s.record.stage))
            }.frame(height:170).chartXAxis { AxisMarks(values:.stride(by:.hour,count:2)) { _ in AxisValueLabel(format:.dateTime.hour()) } }
            Text("Only reported stages appear. Blank gaps mean unknown; they are not counted as sleep.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
