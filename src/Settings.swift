import AppKit
import SwiftUI

// One object, UserDefaults-backed, mirrored to config.env for piroba.sh.
@MainActor
final class Settings: ObservableObject {
    static let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("piroba")
    static let whisperModels = ["mlx-community/whisper-large-v3-turbo", "mlx-community/whisper-small-mlx", "mlx-community/whisper-base-mlx"]

    @Published var autoRecord: Bool       { didSet { save() } }
    @Published var micUID: String         { didSet { save() } }   // "" = system default
    @Published var idleStop: Int          { didSet { save() } }   // seconds of free mic = call over
    @Published var minSeconds: Int        { didSet { save() } }
    @Published var whisper: String        { didSet { save() } }
    @Published var summariser: String     { didSet { save() } }   // "ollama" | "claude" | "none"
    @Published var llm: String            { didSet { save() } }
    @Published private(set) var ollamaModels: [String] = []
    @Published private(set) var launchAtLogin = false
    let claudeInstalled: Bool

    private let d = UserDefaults.standard

    init() {
        autoRecord = d.object(forKey: "autoRecord") as? Bool ?? true
        micUID     = d.string(forKey: "micUID") ?? ""
        idleStop   = d.object(forKey: "idleStop") as? Int ?? 60
        minSeconds = d.object(forKey: "minSeconds") as? Int ?? 60
        whisper    = d.string(forKey: "whisper") ?? Settings.whisperModels[0]
        summariser = d.string(forKey: "summariser") ?? "ollama"
        llm        = d.string(forKey: "llm") ?? "gemma4:12b"
        claudeInstalled = FileManager.default.isExecutableFile(atPath: NSHomeDirectory() + "/.local/bin/claude")
        save()
        refreshExternal()
    }

    func refreshExternal() {
        Task.detached { [weak self] in
            let models = Self.shell("/usr/local/bin/ollama", ["list"])
                .split(separator: "\n").dropFirst()
                .compactMap { $0.split(separator: " ").first.map(String.init) }
            let disabled = Self.shell("/bin/launchctl", ["print-disabled", "gui/\(getuid())"]).contains("\"com.luka.piroba\" => disabled")
            await MainActor.run {
                self?.ollamaModels = models
                self?.launchAtLogin = !disabled
            }
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        let target = "gui/\(getuid())/com.luka.piroba"
        _ = Self.shell("/bin/launchctl", [on ? "enable" : "disable", target])
        launchAtLogin = on
    }

    private func save() {
        d.set(autoRecord, forKey: "autoRecord"); d.set(micUID, forKey: "micUID")
        d.set(idleStop, forKey: "idleStop");     d.set(minSeconds, forKey: "minSeconds")
        d.set(whisper, forKey: "whisper");       d.set(summariser, forKey: "summariser"); d.set(llm, forKey: "llm")
        let env = """
        PIROBA_MODEL=\(whisper)
        PIROBA_SUMMARISER=\(summariser)
        PIROBA_LLM=\(llm)
        PIROBA_MIN_SECONDS=\(minSeconds)

        """
        try? env.write(to: Settings.root.appendingPathComponent("config.env"), atomically: true, encoding: .utf8)
    }

    nonisolated static func shell(_ path: String, _ args: [String]) -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    var back: () -> Void
    @State private var mics: [AudioDevices.Device] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: back) { Image(systemName: "chevron.left") }.buttonStyle(.plain).foregroundStyle(.secondary)
                Text("Settings").font(.callout.weight(.medium))
                Spacer()
            }

            section("Recording") {
                row("Microphone") {
                    Picker("", selection: $settings.micUID) {
                        Text("System default").tag("")
                        ForEach(mics) { Text($0.name).tag($0.uid) }
                    }
                }
                row("Auto-record calls") { Toggle("", isOn: $settings.autoRecord).toggleStyle(.switch) }
                row("Call over after") { stepper($settings.idleStop, 15...300, step: 15, unit: "s idle") }
                row("Ignore under") { stepper($settings.minSeconds, 0...600, step: 30, unit: "s") }
            }

            section("Processing") {
                row("Transcription") {
                    Picker("", selection: $settings.whisper) {
                        ForEach(Settings.whisperModels, id: \.self) { Text($0.split(separator: "/").last.map(String.init) ?? $0).tag($0) }
                    }
                }
                row("Summary") {
                    Picker("", selection: $settings.summariser) {
                        Text("Ollama (local)").tag("ollama")
                        if settings.claudeInstalled { Text("Claude Code").tag("claude") }
                        Text("Transcript only").tag("none")
                    }
                }
                if settings.summariser == "ollama" {
                    row("Model") {
                        Picker("", selection: $settings.llm) {
                            ForEach(settings.ollamaModels.isEmpty ? [settings.llm] : settings.ollamaModels, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
                Text(settings.summariser == "claude"
                     ? "Transcripts are sent to Anthropic via your Claude Code login."
                     : "Everything stays on this Mac.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            section("Integrations") {
                row("Azure DevOps") {
                    Text(settings.claudeInstalled ? "via Claude Code review" : "Claude Code not found")
                        .font(.caption).foregroundStyle(.secondary)
                }
                row("Launch at login") {
                    Toggle("", isOn: Binding(get: { settings.launchAtLogin }, set: { settings.setLaunchAtLogin($0) }))
                        .toggleStyle(.switch)
                }
                row("Meetings folder") {
                    Button("Open") { NSWorkspace.shared.open(Settings.root.appendingPathComponent("meetings")) }.controlSize(.mini)
                }
            }
        }
        .controlSize(.small)
        .labelsHidden()
        .onAppear { mics = AudioDevices.inputs(); settings.refreshExternal() }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary).kerning(0.6)
            c()
        }
    }
    private func row<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack { Text(label).font(.callout); Spacer(); c().frame(maxWidth: 150, alignment: .trailing) }
    }
    private func stepper(_ v: Binding<Int>, _ r: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack(spacing: 4) {
            Text("\(v.wrappedValue) \(unit)").font(.callout).monospacedDigit()
            Stepper("", value: v, in: r, step: step)
        }
    }
}
