import AppKit
import SwiftUI

// The floating capsule shown only while recording. Non-activating so it never
// steals focus from the call; joins all Spaces so it sits over full-screen Teams.
final class PillPanel: NSPanel {
    init(recorder: Recorder, onStop: @escaping () -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 36),
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
        contentView = NSHostingView(rootView: PillView(recorder: recorder, onStop: onStop))
        contentView?.wantsLayer = true
        if let f = NSScreen.main?.visibleFrame {   // top-right, under the menu bar
            setFrameOrigin(NSPoint(x: f.maxX - frame.width - 16, y: f.maxY - frame.height - 12))
        }
        setFrameAutosaveName("pill")               // remembers where you dragged it
    }
}

struct PillView: View {
    @ObservedObject var recorder: Recorder
    var onStop: () -> Void
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(.red).frame(width: 8, height: 8)
                .opacity(pulse ? 1 : 0.35)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            Waveform(levels: recorder.levels).frame(width: 70, height: 16)
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
