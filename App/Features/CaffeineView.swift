import SwiftUI

struct CaffeineView:View {
    @EnvironmentObject private var store:AppStore
    @State private var adding=false
    var body:some View {
        let p=store.data.preferences
        let total=CaffeineAdvice.dailyTotal(store.data.caffeineEntries,on:store.now,zoneID:p.reportingTimeZoneID)
        let cutoff=CaffeineAdvice.cutoff(bedtime:store.plan.bedtime,profile:store.data.profile)
        LumaPage {
            SectionTitle(title:"Protect your next night.",subtitle:"Track caffeine, understand the timing, and choose your own limits.")
            Surface {
                Eyebrow(text:"Today’s logged caffeine")
                Text("\(total.formatted(.number.precision(.fractionLength(0)))) mg").font(.largeTitle.weight(.semibold))
                Text(CaffeineAdvice.message(preferences:p,profile:store.data.profile,total:total)).font(.subheadline)
                if CaffeineAdvice.isAdult(p),store.data.profile?.caffeineContext == .standard,let cap=store.data.profile?.personalCaffeineCapMG { LabeledContent("Your chosen tracking cap",value:"\(cap.formatted()) mg/day") }
                Text("Totals use calendar days in \(p.reportingTimeZoneID). Count all sources, including coffee, tea, energy drinks, pre-workout, chocolate and medicines. Check the product label; serving sizes vary.").font(.caption).foregroundStyle(.secondary)
            }
            Surface {
                Eyebrow(text:"Bedtime-based cutoff")
                Text(cutoff.formatted(date:.abbreviated,time:.shortened)).font(.title2.weight(.semibold))
                Text(store.now >= cutoff ? "You’re past the cutoff for your next planned night. Choose caffeine-free drinks." : "Choose caffeine-free drinks after this time to give your sleep more space.").font(.subheadline)
                Text("\(CaffeineAdvice.cutoffHours(store.data.profile)) hours before planned bedtime, based on your sensitivity answer. An 8-hour buffer follows general sleep guidance; the 10-hour option is a conservative setting. Effects can last longer. This is not a test of your metabolism or permission to consume caffeine before the cutoff.").font(.caption).foregroundStyle(.secondary)
                NavigationLink("Set a caffeine reminder") { NotificationsView() }
            }
            Button("Log caffeine already consumed",systemImage:"plus.circle") { adding=true }.buttonStyle(.borderedProminent)
            NavigationLink("Update my sleep & caffeine profile") { SleepProfileView() }
            SectionTitle(title:"Recent entries")
            if store.data.caffeineEntries.isEmpty { Text("No caffeine logged. Logging is optional.").foregroundStyle(.secondary) }
            ForEach(Array(store.data.caffeineEntries.sorted{$0.date > $1.date}.prefix(30))) { entry in
                Surface {
                    HStack { Text(entry.label).font(.headline);Spacer();Text("\(entry.milligrams.formatted()) mg") }
                    Text(entry.date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)
                    Button("Delete entry",role:.destructive) { store.perform { try store.transact{$0.caffeineEntries.removeAll{$0.id == entry.id}} } }
                }
            }
            DisclosureGroup("Sources & limits") {
                Text("Lotus does not calculate a safe dose from body weight, sleep loss or this questionnaire. Talk with a healthcare professional about individual limits if conditions or medicines apply.").font(.caption)
                Link("Adults & individual sensitivity · FDA",destination:URL(string:"https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much")!)
                Link("Children & teens · American Academy of Pediatrics",destination:URL(string:"https://www.healthychildren.org/English/healthy-living/nutrition/Pages/the-effects-of-caffeine-on-kids-a-parents-guide.aspx")!)
                Link("Caffeine timing · NIH",destination:URL(string:"https://www.nhlbi.nih.gov/health/sleep-deprivation/healthy-sleep-habits")!)
            }
        }.navigationTitle("Caffeine & sleep").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented:$adding) { AddCaffeineView() }
    }
}
private struct AddCaffeineView:View {
    @EnvironmentObject private var store:AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var label=""
    @State private var milligrams=""
    @State private var date=Date()
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                TextField("Drink or product",text:$label)
                TextField("Caffeine in mg · check label",text:$milligrams).keyboardType(.decimalPad)
                DatePicker("Consumed at",selection:$date,in:...Date())
                Text("Log what you already consumed. This is not a recommended dose. Include caffeine from every ingredient and serving.").font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Log caffeine").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save") {
                        do {
                            guard let mg=Double(milligrams.replacingOccurrences(of:",",with:".")) else { throw LumaError.invalid("Enter the caffeine amount in milligrams.") }
                            let text=label.trimmingCharacters(in:.whitespacesAndNewlines)
                            let entry=CaffeineEntry(date:date,milligrams:mg,label:text.isEmpty ? "Caffeine" : text)
                            try entry.validate();try store.transact{$0.caffeineEntries.append(entry)};dismiss()
                        } catch { self.error=error.localizedDescription }
                    }}
                }
        }
    }
}
