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
        if MicWatch.someoneElseIsRecording {
            idleSince = nil
            if !recorder.isRecording, !skipped, ask == nil, Date() >= retryAfter {
                settings.callMode == "auto" ? startRecording() : showAsk()
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

    private func showAsk() {
        let panel = AskPanel(record: { [weak self] in self?.dismissAsk(); self?.startRecording() },
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
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: meetingsDir, includingPropertiesForKeys: nil)) ?? []
        meetings = dirs.filter { $0.hasDirectoryPath }.map { url in
            let id = url.lastPathComponent
            let status: Meeting.Status
            if recorder.dir?.lastPathComponent == id { status = .recording }
            else if working.contains(id) { status = .working }
            else if fm.fileExists(atPath: url.appendingPathComponent("digest.md").path) { status = .ready }
            else { status = .failed }
            return Meeting(id: id, url: url, status: status)
        }.sorted { $0.id > $1.id }
    }

    // piroba://record · piroba://stop · piroba://actions/<id>
    private func handleURL(_ url: URL) {
        switch url.host {
        case "record": if !recorder.isRecording { dismissAsk(); startRecording(manual: true) }; return
        case "stop":   if recorder.isRecording { stopRecording() }; return
        default: break
        }
        guard url.host == "actions" else { return }
        let id = url.lastPathComponent
        if FileManager.default.fileExists(atPath: meetingsDir.appendingPathComponent(id).appendingPathComponent("digest.md").path) {
            openActions(meetingsDir.appendingPathComponent(id))
        }
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

struct MenuView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var settings: Settings
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings { SettingsView { showSettings = false } } else { main }
        }
        .padding(14)
        .frame(width: 280)
        .onAppear { app.refresh() }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(app.recorder.isRecording ? .red : .secondary.opacity(0.4)).frame(width: 7, height: 7)
                Text(app.statusLine).font(.callout)
                Spacer()
                Button(app.recorder.isRecording ? "Stop" : "Record") {
                    app.recorder.isRecording ? app.stopRecording() : app.startRecording(manual: true)
                }
                .controlSize(.small)
            }
            Divider()
            if app.meetings.isEmpty {
                Text("No meetings yet").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(app.meetings.prefix(8)) { m in MeetingRow(m: m) }
            }
            Divider()
            HStack {
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MeetingRow: View {
    @EnvironmentObject var app: AppState
    let m: Meeting
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(tint).frame(width: 14)
            Text(m.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                .font(.callout)
            Spacer()
            if m.status == .ready {
                if hover { Image(systemName: "arrow.up.forward.square").font(.caption).foregroundStyle(.secondary) }
            } else if m.status == .failed {
                Button("Retry") { app.process(m.url) }.controlSize(.mini)
            } else {
                Text(m.status == .recording ? "recording" : "working…").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2).contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { if m.status == .ready { app.openActions(m.url) } }
    }

    private var icon: String {
        switch m.status {
        case .recording: "record.circle"
        case .working: "hourglass"
        case .ready: "checkmark.circle"
        case .failed: "exclamationmark.circle"
        }
    }
    private var tint: Color { m.status == .recording ? .red : m.status == .failed ? .orange : .secondary }
}
