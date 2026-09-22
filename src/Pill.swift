import AppKit
import SwiftUI

// The floating capsule shown only while recording. Non-activating so it never
// steals focus from the call; joins all Spaces so it sits over full-screen Teams.
final class PillPanel: NSPanel {
    init(recorder: Recorder, showWave: Bool, onStop: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: showWave ? 200 : 120, height: 36),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false   // AppState holds a reference; closing must not free the panel
        contentView = NSHostingView(rootView: PillView(recorder: recorder, showWave: showWave, onStop: onStop))
        contentView?.wantsLayer = true
        if let f = NSScreen.main?.visibleFrame {   // top-right, under the menu bar
            setFrameOrigin(NSPoint(x: f.maxX - frame.width - 16, y: f.maxY - frame.height - 12))
        }
        setFrameAutosaveName("pill")               // remembers where you dragged it
    }
}

struct PillView: View {
    @ObservedObject var recorder: Recorder
    var showWave: Bool
    var onStop: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(.red).frame(width: 8, height: 8)
                .opacity(pulse ? 1 : 0.35)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            if showWave { Waveform(levels: recorder.levels).frame(width: 70, height: 16) }
            Text(clock(recorder.elapsed))
                .font(.system(.caption, design: .monospaced)).monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Button(action: onStop) {
                Image(systemName: "stop.fill").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help("Stop recording")
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08)))
        .onAppear { pulse = true }
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%02d:%02d", s / 60, s % 60)
    }
}

struct Waveform: View {
    let levels: [Float]
    var body: some View {
        GeometryReader { geo in
            let slot = geo.size.width / CGFloat(levels.count)
            HStack(alignment: .center, spacing: slot * 0.45) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule().fill(.primary.opacity(0.75))
                        .frame(width: slot * 0.55, height: max(2, CGFloat(levels[i]) * geo.size.height))
                }
            }
            .frame(height: geo.size.height)
            .animation(.linear(duration: 0.08), value: levels)
        }
    }
}


// Shown under the menu bar icon when another app opens the mic. One button.
// Never takes focus; leaves by itself when the call ends or after 20 s.
final class AskPanel: NSPanel {
    static let size = NSSize(width: 172, height: 40)   // minimum; 32 pt pill + 8 pt caret

    init(who: String, record: @escaping () -> Void) {
        super.init(contentRect: NSRect(origin: .zero, size: AskPanel.size),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AskView(who: who, record: record))
        contentView = host
        setContentSize(NSSize(width: min(max(host.fittingSize.width, AskPanel.size.width), 260), height: AskPanel.size.height))
        // Anchor: centred under the status item. SwiftUI's MenuBarExtra owns an NSStatusBarWindow;
        // its frame is the icon's frame on the menu bar.
        let item = NSApp.windows.first { $0.className.contains("StatusBarWindow") }?.frame
        let screen = (item.flatMap { f in NSScreen.screens.first { $0.frame.contains(f.origin) } } ?? NSScreen.main)?.frame ?? .zero
        let x = item.map { $0.midX - frame.width / 2 } ?? (screen.maxX - frame.width - 16)
        let y = item.map { $0.minY - frame.height - 2 } ?? (screen.maxY - 24 - frame.height - 8)
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct AskView: View {
    var who: String
    var record: () -> Void
    private var name: String { who.count > 24 ? String(who.prefix(23)) + "…" : who }

    var body: some View {
        VStack(spacing: 0) {
            Triangle().fill(.regularMaterial).frame(width: 16, height: 8)
                .overlay(Triangle().stroke(.primary.opacity(0.08), lineWidth: 1))
            HStack(spacing: 8) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text(name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                Button("Record", action: record).controlSize(.small).fixedSize()
            }
            .padding(.leading, 12).padding(.trailing, 6)
            .frame(minWidth: AskPanel.size.width, maxWidth: 260)
            .frame(height: 32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08)))
        }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath()
        return p
    }
}
