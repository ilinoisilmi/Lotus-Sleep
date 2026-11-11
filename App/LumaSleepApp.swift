import SwiftUI
@main struct LumaSleepApp: App {
    @StateObject private var store=AppStore.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .preferredColorScheme(store.data.preferences.appearance == "dark" ? .dark : store.data.preferences.appearance == "light" ? .light : nil)
                .tint(Luma.lavender)
                .onChange(of:scenePhase) { _, phase in if phase == .active { Task { await store.foreground() } } }
        }
    }
}
struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Group {
            if let error=store.recoveryMessage { RecoveryView(error:error) }
            else if !store.data.preferences.onboardingComplete { OnboardingView() }
            else {
                TabView(selection:$store.selectedTab) {
                    NavigationStack { TodayView() }.tabItem { Label("Today",systemImage:"sun.horizon") }.tag(0)
                    NavigationStack { TrackView() }.tabItem { Label("Track",systemImage:"moon.zzz") }.tag(1)
                    NavigationStack { HistoryView() }.tabItem { Label("History",systemImage:"chart.bar.xaxis") }.tag(2)
                    NavigationStack { InsightsView() }.tabItem { Label("Insights",systemImage:"waveform.path") }.tag(3)
                    NavigationStack { SettingsView() }.tabItem { Label("Settings",systemImage:"slider.horizontal.3") }.tag(4)
                }
                .safeAreaInset(edge:.top,spacing:0) {
                    if store.isDemo {
                        HStack { Label("DEMO · sample history",systemImage:"sparkles"); Spacer(); Button("Exit") { store.toggleDemo() } }
                            .font(.caption.weight(.semibold)).padding(10).background(Luma.warm.opacity(0.18))
                    }
                }
            }
        }
        .transaction { if reduceMotion { $0.animation=nil } }
        .alert("Lotus Sleep",isPresented:Binding(get:{store.message != nil},set:{if !$0 { store.message=nil }})) { Button("OK",role:.cancel) {} } message: { Text(store.message ?? "") }
        .onOpenURL { url in if url.scheme == "lumasleep" { store.selectedTab=url.host == "track" ? 1 : 0 } }
        .sheet(isPresented:$store.openMorningInbox) {
            NavigationStack { MorningInboxView().toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { store.openMorningInbox=false } } } }
        }
    }
}
