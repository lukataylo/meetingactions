import AppKit
import Combine
import SwiftUI

// URL routing via the app delegate — SwiftUI owns the kAEGetURL Apple event, so a manual handler loses.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var onURL: ((URL) -> Void)?
    func application(_ application: NSApplication, open urls: [URL]) { urls.forEach { AppDelegate.onURL?($0) } }
}

@main
struct PirobaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var settings = Settings()
    @StateObject private var app: AppState
    init() { let s = Settings(); _settings = StateObject(wrappedValue: s); _app = StateObject(wrappedValue: AppState(settings: s)) }

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(app).environmentObject(settings)
        } label: {
            Image(systemName: app.recorder.isRecording ? "waveform.circle.fill" : "waveform")
        }
        .menuBarExtraStyle(.window)
    }
}

struct Meeting: Identifiable {
    enum Status { case recording, working, ready, failed }
    let id: String          // folder name, yyyy-MM-dd_HHmm
    let url: URL
    let status: Status
    var summary: String? = nil   // "4 actions · 2 left"
    var done = false
    var date: Date { Meeting.fmt.date(from: id) ?? .distantPast }
    static let fmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HHmm"; return f }()
}

@MainActor
final class AppState: ObservableObject {
    let settings: Settings
    @Published var meetings: [Meeting] = []
    @Published var working: Set<String> = []
    private(set) var recorder = Recorder() { didSet { bindRecorder() } }

    let root = Settings.root
    var meetingsDir: URL { root.appendingPathComponent("meetings") }

    private var pill: PillPanel?
    private var ask: AskPanel?
    private var askedAt: Date?
    private var skipped = false          // "Skip" holds until the mic goes free again
    private var retryAfter = Date.distantPast
    private var panels: [String: (ActionsPanel, ActionsStore)] = [:]
    let reviews = ReviewsStore()
    private var reviewsPanel: ReviewsPanel?
    private var claudeWindow: Int?   // Terminal window id hosting the interactive claude session
    private var manual = false
    private var idleSince: Date?
    private var bag = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings
        bindRecorder()
        AppDelegate.onURL = { [weak self] url in self?.handleURL(url) }   // piroba://actions/<meeting-id>
        refresh()
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func bindRecorder() {
        bag.removeAll()
        recorder.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
    }

    var statusLine: String {
        if recorder.isRecording { return manual ? "Recording" : "Recording call" }
        if ask != nil { return "Call detected — record?" }
        if !working.isEmpty { return "Transcribing…" }
        switch settings.callMode {
        case "auto": return "Listening — will record calls"
        case "ask":  return "Listening for calls"
        default:     return "Not watching for calls"
        }
    }

    private func poll() {
        guard settings.callMode != "off", !manual else { return }
        let ignored = settings.ignoredSet
        let holders = MicWatch.holders().filter { !ignored.contains($0.bundle) }   // Granola etc. alone ≠ a call
        if !holders.isEmpty {
            idleSince = nil
            if !recorder.isRecording, !skipped, ask == nil, Date() >= retryAfter {
                settings.callMode == "auto" ? startRecording() : showAsk(holders.map(\.name))
            }
            if let askedAt, Date().timeIntervalSince(askedAt) > 90 { dismissAsk(); skipped = true }   // unanswered = skip
        } else {
            skipped = false
            if ask != nil { dismissAsk() }
            if recorder.isRecording {
                idleSince = idleSince ?? Date()
                if Date().timeIntervalSince(idleSince!) >= Double(settings.idleStop) { stopRecording() }
            }
        }
    }

    private func showAsk(_ names: [String]) {
        let who = names.prefix(2).joined(separator: " and ")
        let panel = AskPanel(who: who, record: { [weak self] in self?.dismissAsk(); self?.startRecording() },
                             skip:   { [weak self] in self?.dismissAsk(); self?.skipped = true })
        panel.orderFrontRegardless()
        ask = panel; askedAt = Date()
        NSSound(named: "Tink")?.play()
    }

    private func dismissAsk() {
        let old = ask; ask = nil; askedAt = nil
        old?.orderOut(nil)
        DispatchQueue.main.async { old?.close() }
    }

    func startRecording(manual: Bool = false) {
        self.manual = manual
        let dir = meetingsDir.appendingPathComponent(Meeting.fmt.string(from: Date()))
        recorder.deviceUID = settings.micUID
        recorder.start(into: dir) { [weak self] error in self?.started(dir, error) }
    }

    private var fallingBack = false

    private func started(_ dir: URL, _ error: Error?) {
        do {
            if let error {
                plog("record failed: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: dir)
                retryAfter = Date().addingTimeInterval(60)   // don't spam a new folder every 5 s
                self.manual = false
                if (error as NSError).code == Recorder.hungCode {
                    recorder = Recorder()   // the old one's queue is dead
                    if let mic = Recorder.builtInMicUID, settings.micUID != mic, !fallingBack {
                        plog("falling back to the built-in microphone")
                        fallingBack = true
                        recorder.deviceUID = mic
                        recorder.start(into: dir) { [weak self] e in self?.started(dir, e) }
                        return
                    }
                }
                fallingBack = false
                refresh()
                return
            }
            fallingBack = false
            plog("recording -> \(dir.lastPathComponent) via \(recorder.deviceName)")
            if settings.pill != "hidden" {
                let panel = PillPanel(recorder: recorder, showWave: settings.pill == "wave") { [weak self] in self?.stopRecording() }
                panel.orderFrontRegardless()
                pill = panel
                plog("pill frame \(panel.frame)")
            }
            refresh()
        }
    }

    func stopRecording() {
        manual = false
        idleSince = nil
        // orderOut, and release on the next turn: the Stop button's gesture is still dispatching
        // inside this panel when we get here, so tearing it down synchronously is a use-after-free.
        let old = pill; pill = nil
        old?.orderOut(nil)
        DispatchQueue.main.async { old?.close() }
        recorder.stop { [weak self] dir in
            if let dir { self?.process(dir) } else { self?.refresh() }
        }
    }

    func process(_ dir: URL) {
        working.insert(dir.lastPathComponent)
        refresh()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [root.appendingPathComponent("piroba.sh").path, "process", dir.path]
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/opt/anaconda3/bin:/usr/bin:/bin:" + NSHomeDirectory() + "/.local/bin"
        p.environment = env
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.working.remove(dir.lastPathComponent); self?.refresh()
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("digest.md").path) { self?.openActions(dir) }
            }
        }
        do { try p.run() } catch { NSLog("process failed: \(error)"); working.remove(dir.lastPathComponent) }
    }

    func refresh() {
        reviews.load()
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: meetingsDir, includingPropertiesForKeys: nil)) ?? []
        meetings = dirs.filter { $0.hasDirectoryPath }.map { url in
            let id = url.lastPathComponent
            let status: Meeting.Status
            if recorder.dir?.lastPathComponent == id { status = .recording }
            else if working.contains(id) { status = .working }
            else if fm.fileExists(atPath: url.appendingPathComponent("digest.md").path) { status = .ready }
            else { status = .failed }
            var m = Meeting(id: id, url: url, status: status)
            if status == .ready {
                let store = ActionsStore(dir: url)   // parses digest.md / actions.json; both are tiny
                let left = store.items.filter { !$0.done }.count
                m.summary = store.items.isEmpty ? "No actions" : left == 0 ? "\(store.items.count) actions · all done" : "\(store.items.count) actions · \(left) left"
                m.done = !store.items.isEmpty && left == 0
            }
            return m
        }.sorted { $0.id > $1.id }
    }

    // piroba://record · piroba://stop · piroba://actions/<id>
    private func handleURL(_ url: URL) {
        switch url.host {
        case "record": if !recorder.isRecording { dismissAsk(); startRecording(manual: true) }; return
        case "stop":   if recorder.isRecording { stopRecording() }; return
        case "reviews": openReviews(); return
        default: break
        }
        guard url.host == "actions" else { return }
        let id = url.lastPathComponent
        if FileManager.default.fileExists(atPath: meetingsDir.appendingPathComponent(id).appendingPathComponent("digest.md").path) {
            openActions(meetingsDir.appendingPathComponent(id))
        }
    }

    func openReviews() {
        reviews.load()
        if reviewsPanel == nil { reviewsPanel = ReviewsPanel(store: reviews) }
        reviewsPanel?.makeKeyAndOrderFront(nil)
    }

    func openActions(_ dir: URL) {
        let id = dir.lastPathComponent
        if let (panel, _) = panels[id] { panel.makeKeyAndOrderFront(nil); return }
        let store = ActionsStore(dir: dir)
        let panel = ActionsPanel(store: store) { [weak self] item in self?.sendToClaude(item, meeting: id) }
        panels[id] = (panel, store)
        panel.makeKeyAndOrderFront(nil)
    }

    // One interactive claude session in the xTrade workspace (ADO MCP + /ticket live there);
    // each action is pasted into it. Claude Code keeps a pasted trailing newline as text,
    // so a second bare `do script ""` is the Enter that actually submits.
    func sendToClaude(_ item: ActionItem, meeting: String) {
        let store = panels[meeting]?.1
        let when = Meeting.fmt.date(from: meeting).map { $0.formatted(.dateTime.weekday(.wide).day().month(.wide)) } ?? meeting
        let context = "Context: from my meeting on \(when)" + (store?.about.isEmpty == false ? " — \(store!.about)" : "") + "."
        let ask = item.ticket
            // /ticket is the workspace skill: drafts, places under the right Feature, then asks before filing
            ? "/ticket \(item.text)\(item.detail.isEmpty ? "" : " — \(item.detail)"). \(context)"
            : "\(context) I committed to: \(item.text). Start on it now — read the code, ADO board and docs you need, and do the work end to end without checking in first. The only pause is before writing to Azure DevOps or sending anything on my behalf: show me the draft, then file on my OK."
        let text = ask.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = claudeWindow.map { id in """
            tell application "Terminal"
                activate
                if exists window id \(id) then
                    do script "\(text)" in window id \(id)
                    delay 0.3
                    do script "" in window id \(id)
                    return \(id)
                end if
            end tell
            """ } ?? "return 0"
        var err: NSDictionary?
        let reused = NSAppleScript(source: script)?.executeAndReturnError(&err).int32Value ?? 0
        if reused == 0 {
            let boot = """
            tell application "Terminal"
                activate
                set t to do script "cd ~/Documents/xTrade && claude"
                delay 5
                do script "\(text)" in t
                delay 0.3
                do script "" in t
                return id of window 1
            end tell
            """
            if let id = NSAppleScript(source: boot)?.executeAndReturnError(&err).int32Value, id != 0 { claudeWindow = Int(id) }
        }
        if let err { NSLog("send failed: \(err)") }
    }
}

// Friendly day label: Today 10:17 · Yesterday 14:50 · Fri 16:00 · 2 Sep 13:45
func friendly(_ d: Date) -> String {
    let cal = Calendar.current
    let time = d.formatted(.dateTime.hour().minute())
    if cal.isDateInToday(d) { return "Today \(time)" }
    if cal.isDateInYesterday(d) { return "Yesterday \(time)" }
    if let week = cal.date(byAdding: .day, value: -6, to: Date()), d > week { return "\(d.formatted(.dateTime.weekday(.abbreviated))) \(time)" }
    return "\(d.formatted(.dateTime.day().month(.abbreviated))) \(time)"
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.semibold)).kerning(0.6).foregroundStyle(.tertiary)
            .padding(.top, 6).padding(.bottom, 2)
    }
}

// One tappable line in the menu: glyph · title · trailing text · chevron on hover.
struct MenuRow<Trailing: View>: View {
    let icon: String
    var tint: Color = .secondary
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            trailing()
            if action != nil {
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    .foregroundStyle(.quaternary).opacity(hover ? 1 : 0)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(hover && action != nil ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { action?() }
    }
}

struct MenuView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: Settings
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings { SettingsView { showSettings = false }.padding(14) } else { main }
        }
        .frame(width: 300)
        .onAppear { app.refresh() }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 2) {
            // status
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle().fill(app.recorder.isRecording ? Color.red.opacity(0.15) : Color.primary.opacity(0.06)).frame(width: 30, height: 30)
                    Image(systemName: app.recorder.isRecording ? "waveform" : "phone").font(.system(size: 13))
                        .foregroundStyle(app.recorder.isRecording ? .red : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.statusLine).font(.callout.weight(.medium))
                    Text(app.recorder.isRecording ? clock(app.recorder.elapsed) + " · " + app.recorder.deviceName : modeLine)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(app.recorder.isRecording ? "Stop" : "Record") {
                    app.recorder.isRecording ? app.stopRecording() : app.startRecording(manual: true)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 8)

            Divider().padding(.horizontal, 8)

            SectionLabel(text: "Reviews").padding(.horizontal, 8)
            MenuRow(icon: "eye", tint: app.reviews.waiting > 0 ? .accentColor : .secondary,
                    title: app.reviews.waiting > 0 ? "\(app.reviews.waiting) waiting for you" : "Nothing waiting",
                    subtitle: app.reviews.items.isEmpty ? nil : "\(app.reviews.items.count) in the queue",
                    action: { app.openReviews() }) { EmptyView() }

            SectionLabel(text: "Meetings").padding(.horizontal, 8)
            if app.meetings.isEmpty {
                Text("Nothing captured yet").font(.callout).foregroundStyle(.tertiary).padding(.horizontal, 16).padding(.vertical, 6)
            } else {
                ForEach(app.meetings.prefix(6)) { m in MeetingRow(m: m) }
            }

            Divider().padding(.horizontal, 8).padding(.top, 6)
            HStack {
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .padding(8)
    }

    private var modeLine: String {
        switch settings.callMode {
        case "auto": "Records calls automatically"
        case "ask":  "Asks before recording"
        default:     "Manual only"
        }
    }
    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t); return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct MeetingRow: View {
    @EnvironmentObject var app: AppState
    let m: Meeting

    var body: some View {
        MenuRow(icon: icon, tint: tint, title: friendly(m.date), subtitle: m.summary,
                action: m.status == .ready ? { app.openActions(m.url) } : nil) {
            switch m.status {
            case .failed:    Button("Retry") { app.process(m.url) }.controlSize(.mini)
            case .recording: Text("recording").font(.caption).foregroundStyle(.red)
            case .working:   ProgressView().controlSize(.mini)
            case .ready:     EmptyView()
            }
        }
    }

    private var icon: String {
        switch m.status {
        case .recording: "record.circle"
        case .working: "hourglass"
        case .ready: m.done ? "checkmark.circle.fill" : "checklist"
        case .failed: "exclamationmark.circle"
        }
    }
    private var tint: Color { m.status == .recording ? .red : m.status == .failed ? .orange : m.done ? .green : .secondary }
}
