import SwiftUI

/// Crops one tile from the original vector asset. No network images or animation loop.
struct CompanionPortrait:View {
    let pet:RestPet
    let stage:Int
    var body:some View {
        GeometryReader { proxy in
            Image("CompanionSheet").resizable()
                .frame(width:proxy.size.width*5,height:proxy.size.width*4)
                .offset(x:-CGFloat(max(0,min(4,stage)))*proxy.size.width,y:-CGFloat(pet.row)*proxy.size.width)
        }.aspectRatio(1,contentMode:.fit).clipped()
            .accessibilityLabel("\(pet.name), \(pet.species), \(CompanionState.stageNames[max(0,min(4,stage))])")
    }
}
struct RestCompanionCard:View {
    @EnvironmentObject private var store:AppStore
    var body:some View {
        let pet=store.data.companions.selected
        NavigationLink { CompanionView() } label: {
            Surface {
                HStack(spacing:12) {
                    CompanionPortrait(pet:pet,stage:store.data.companions.stage(for:pet)).frame(width:88,height:88)
                    VStack(alignment:.leading,spacing:7) {
                        Text("\(store.restStreak?.current ?? 0) good-rest \((store.restStreak?.current ?? 0) == 1 ? "day" : "days")").font(.headline)
                        Text("\(pet.name) · \(CompanionState.stageNames[store.data.companions.stage(for:pet)])").font(.caption).foregroundStyle(.secondary)
                        Text("View your streak & companions").font(.caption)
                    }
                    Spacer(minLength:0);Image(systemName:"chevron.right").font(.caption)
                }
            }
        }.buttonStyle(.plain)
    }
}
struct CompanionView:View {
    @EnvironmentObject private var store:AppStore
    var body:some View {
        let state=store.data.companions,pet=state.selected,stage=state.stage(for:pet)
        LumaPage {
            SectionTitle(title:"A quiet companion.",subtitle:"Choose who keeps you company as you build your sleep routine.")
            Surface {
                CompanionPortrait(pet:pet,stage:stage).frame(maxWidth:230).frame(maxWidth:.infinity)
                Text(pet.name).font(.title2.weight(.semibold))
                Text(CompanionState.stageNames[stage]).foregroundStyle(.secondary)
                HStack {
                    VStack(alignment:.leading) { Text("\(store.restStreak?.current ?? 0)").font(.largeTitle.monospacedDigit());Text("Current streak").font(.caption) }
                    Spacer()
                    VStack(alignment:.trailing) { Text("\(store.restStreak?.best ?? 0)").font(.largeTitle.monospacedDigit());Text("Best in 366 days").font(.caption) }
                }
                if stage < 4 {
                    let next=CompanionState.milestones[stage+1]
                    Text("Next look: a \(next)-day good-rest streak with \(pet.name) selected when that day is logged.").font(.subheadline)
                    ProgressView(value:Double(min(next,store.restStreak?.current ?? 0)),total:Double(next)).tint(Luma.lavender)
                } else { Text("All five looks unlocked for \(pet.name).").font(.subheadline) }
                if store.restStreak?.waitingForLog == true { Text("A completed sleep day is missing a log. Add it to verify your streak; missing sleep data is unknown.").font(.caption).foregroundStyle(.secondary) }
                Text("Your companion keeps every look you have earned, even after a difficult night. Nothing needs feeding or rescuing.").font(.caption).foregroundStyle(.secondary)
            }
            SectionTitle(title:"Choose your companion")
            LazyVGrid(columns:[GridItem(.adaptive(minimum:140))],spacing:16) {
                ForEach(RestPet.allCases,id:\.self) { option in
                    Button { store.selectCompanion(option) } label: {
                        Surface {
                            CompanionPortrait(pet:option,stage:state.stage(for:option))
                            HStack { Text(option.name).font(.headline);Spacer();if option == pet { Image(systemName:"checkmark.circle.fill") } }
                            Text(option.species).font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("companion."+option.rawValue).accessibilityLabel("Choose \(option.name), \(option.species)\(option == pet ? ", selected" : "")")
                }
            }
            SectionTitle(title:"Five small changes")
            LazyVGrid(columns:[GridItem(.adaptive(minimum:100))]) {
                ForEach(0..<5,id:\.self) { index in
                    VStack(alignment:.leading,spacing:5) {
                        CompanionPortrait(pet:pet,stage:index).opacity(index <= stage ? 1 : 0.55)
                        Text(CompanionState.stageNames[index]).font(.caption.weight(.medium))
                        Text(index == 0 ? "Available" : "\(CompanionState.milestones[index]) days\(index <= stage ? " · earned" : "")").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Surface {
                Text("How good-rest days count").font(.headline)
                Text("The same rules as your seven-day review: recorded sleep reaching at least your target minus 30 minutes, and a 4–5 quality rating if you entered one. Confirmed naps count. An unfinished current day does not break the previous streak. A completed missing day pauses verification until you log it; mixed and needs-attention days start a new run.").font(.subheadline).foregroundStyle(.secondary)
                Text("One day's progress goes to one companion. Switching does not reuse that day. These are encouraging diary milestones, not a medical assessment of your sleep.").font(.caption).foregroundStyle(.secondary)
                Toggle("Show companion on Today",isOn:Binding(get:{store.data.preferences.showCompanion ?? true},set:{value in store.updatePreferences{$0.showCompanion=value}}))
            }
        }.navigationTitle("Rest companions").navigationBarTitleDisplayMode(.inline).onAppear{store.refreshCompanion()}
    }
}
