import SwiftUI
struct OnboardingView:View {
    @EnvironmentObject private var store:AppStore
    @State private var age="13–17"
    @State private var target=9.0
    var body:some View {
        NavigationStack {
            LumaPage {
                Image("AppMark").resizable().frame(width:82,height:82).clipShape(RoundedRectangle(cornerRadius:23)).padding(.top,24).accessibilityHidden(true)
                Eyebrow(text:"Lotus Sleep")
                Text("Make space\nfor better rest.").font(.system(.largeTitle,design:.rounded,weight:.semibold))
                Text("A calm place for your nights, your energy, and the habits that connect them.").font(.title3).foregroundStyle(.secondary)
                Surface {
                    Label("Works without a wearable",systemImage:"iphone")
                    Label("Your records stay on this iPhone",systemImage:"lock.shield")
                    Label("Estimates are always labeled",systemImage:"checkmark.seal")
                }
                Surface {
                    Text("Start with a sleep target").font(.headline)
                    Picker("Age range",selection:$age) { Text("13–17").tag("13–17"); Text("18–60").tag("18–60"); Text("61–64").tag("61–64"); Text("65+").tag("65+") }.onChange(of:age) { _,new in target=new == "13–17" ? 9 : 8 }
                    Stepper("\(target.formatted()) hours",value:$target,in:(age == "13–17" ? 8.0 : 7.0)...12,step:0.25)
                    Text(age == "13–17" ? "CDC guidance for ages 13–17 is 8–10 hours. Nine is a starting target, not a measurement of your personal need." : "CDC guidance is 7+ hours for ages 18–60, 7–9 for 61–64, and 7–8 for 65+. Your needs and circumstances may vary.").font(.footnote).foregroundStyle(.secondary)
                    Link("Read CDC sleep guidance",destination:URL(string:"https://www.cdc.gov/sleep/about/index.html")!)
                }
                PrimaryButton(title:"Start my sleep diary") { store.updatePreferences { $0.ageBand=age; $0.targetHours=target; $0.onboardingComplete=true } }
                Button("Explore a clearly labeled demo") { store.toggleDemo() }.frame(maxWidth:.infinity)
                Text("Health, motion, microphone, alarms and notifications are requested only when you choose those features.").font(.caption).foregroundStyle(.secondary)
            }.navigationBarHidden(true)
        }
    }
}
