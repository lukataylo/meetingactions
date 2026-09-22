import AppKit
import SwiftUI

struct ActionItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var detail = ""         // e.g. "Bug · Verify the stamp cap still blocks facility creation in UAT"
    var ticket = false      // came from "Proposed ADO items"
    var done = false
    var sent = false
}

// Per-meeting list, parsed once from digest.md, then owned by actions.json.
@MainActor
final class ActionsStore: ObservableObject {
    @Published var items: [ActionItem] { didSet { if items != oldValue { save() } } }
    @Published var about = ""
    let dir: URL
    private var file: URL { dir.appendingPathComponent("actions.json") }

    init(dir: URL) {
        self.dir = dir
        let md = (try? String(contentsOf: dir.appendingPathComponent("digest.md"), encoding: .utf8)) ?? ""
        about = Self.section("What this was about", in: md).first ?? ""
        let file = dir.appendingPathComponent("actions.json")
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([ActionItem].self, from: data) {
            items = saved
        } else {
            items = Self.section("Actions I committed to", in: md).compactMap(Self.bullet).map { ActionItem(text: $0) }
                  + Self.section("Proposed ADO items", in: md).compactMap(Self.bullet).map(Self.ticketItem)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: file) }
    }

    // lines under "## <title>" up to the next "## "
    private static func section(_ title: String, in md: String) -> [String] {
        var out: [String] = [], inside = false
        for raw in md.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") { inside = line.lowercased().contains(title.lowercased()); continue }
            if inside, !line.isEmpty { out.append(line) }
        }
        return out
    }

    // "- [ ] **Title** — PBI — desc" / "- text" / "1. text"  ->  "Title — PBI — desc"; drops "None"
    // "Title: X | Type: Bug | Description: Y"  or  "X — Bug — Y"  ->  text X, detail "Bug · Y"
    private static func ticketItem(_ s: String) -> ActionItem {
        let parts = s.components(separatedBy: s.contains(" | ") ? " | " : " — ").map {
            $0.replacingOccurrences(of: #"^(Title|Type|Description):\s*"#, with: "", options: .regularExpression)
              .trimmingCharacters(in: .whitespaces)
        }
        guard parts.count > 1 else { return ActionItem(text: s, ticket: true) }
        return ActionItem(text: parts[0], detail: parts.dropFirst().joined(separator: " · "), ticket: true)
    }

    private static func bullet(_ line: String) -> String? {
        var s = line
        for p in ["- [ ] ", "- [x] ", "- ", "* ", "• "] where s.hasPrefix(p) { s.removeFirst(p.count) }
        if let r = s.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) { s.removeSubrange(r) }
        s = s.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        guard s.count > 3, !["none", "none.", "nothing", "nothing."].contains(s.lowercased()) else { return nil }
        guard s != line || line.hasPrefix("-") || line.hasPrefix("*") else { return nil }   // skip prose paragraphs
        return s
    }
}

final class ActionsPanel: NSPanel {
    init(store: ActionsStore, send: @escaping (ActionItem) -> Void) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
                   styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        level = .floating
        collectionBehavior = [.moveToActiveSpace]
        isReleasedWhenClosed = false
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        let host = NSHostingView(rootView: ActionsView(store: store, send: send))
        contentView = host
        setContentSize(host.fittingSize)
        setFrameAutosaveName("actions")
        if frame.origin == .zero, let f = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: f.maxX - frame.width - 24, y: f.maxY - frame.height - 60))
        }
    }
}

// 8-pt grid: margin 24 · checkbox 20 · gap 12 → text at x=56 · row padding 10/12
struct ActionsView: View {
    @ObservedObject var store: ActionsStore
    var send: (ActionItem) -> Void
    private var left: Int { store.items.filter { !$0.done }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(caption: title, title: "Actions", subtitle: store.about)

            if store.items.isEmpty {
                Text("Nothing to do from this one.").font(.system(size: 14)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 24).padding(.bottom, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach($store.items) { $item in ActionRow(item: $item, send: { send(item) }) }
                }
                .padding(.horizontal, 12).padding(.bottom, 8)
            }

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1).padding(.horizontal, 24)
            HStack {
                Text(left == 0 ? "All done" : "\(left) left").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Open digest") { NSWorkspace.shared.open(store.dir.appendingPathComponent("digest.md")) }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 440)
        .background(.regularMaterial)
        .gridOverlay()
    }

    private var title: String {
        Meeting.fmt.date(from: store.dir.lastPathComponent).map(friendly) ?? store.dir.lastPathComponent
    }
}

struct ActionRow: View {
    @Binding var item: ActionItem
    var send: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { withAnimation(.snappy(duration: 0.18)) { item.done.toggle() } } label: {
                ZStack {
                    Circle().strokeBorder(item.done ? Color.accentColor : .secondary.opacity(0.45), lineWidth: 1.5)
                    if item.done {
                        Circle().fill(Color.accentColor)
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)   // optical: centre on the first 22-pt text line

            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.system(size: 15))
                    .lineSpacing(2)
                    .strikethrough(item.done, color: .secondary)
                    .foregroundStyle(item.done ? .tertiary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                if item.ticket {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("ADO").font(.system(size: 9, weight: .semibold)).kerning(0.5)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                        if !item.detail.isEmpty {
                            Text(item.detail).font(.system(size: 12)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .foregroundStyle(item.done ? .quaternary : .secondary)
                }
            }
            Spacer(minLength: 8)

            if item.sent {
                Image(systemName: "paperplane.fill").font(.system(size: 12)).foregroundStyle(.tertiary).help("Sent to Claude")
                    .frame(width: 24, height: 22)
            } else if hover && !item.done {
                Button(action: { item.sent = true; send() }) {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 20)).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain).help("Send to Claude Code")
                .frame(width: 24, height: 22)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(hover ? Color.primary.opacity(0.04) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

// Design aid: `defaults write com.luka.piroba showGrid -bool true` draws the 8-pt grid and the
// 24-pt margins over every panel. Off by default; nothing else reads the flag.
struct GridOverlay: ViewModifier {
    let on = UserDefaults.standard.bool(forKey: "showGrid")
    func body(content: Content) -> some View {
        content.overlay {
            if on {
                Canvas { ctx, size in
                    var minor = Path(); var major = Path()
                    for x in stride(from: 0, through: size.width, by: 8) {
                        if Int(x) % 40 == 0 { major.move(to: .init(x: x, y: 0)); major.addLine(to: .init(x: x, y: size.height)) }
                        else { minor.move(to: .init(x: x, y: 0)); minor.addLine(to: .init(x: x, y: size.height)) }
                    }
                    for y in stride(from: 0, through: size.height, by: 8) {
                        if Int(y) % 40 == 0 { major.move(to: .init(x: 0, y: y)); major.addLine(to: .init(x: size.width, y: y)) }
                        else { minor.move(to: .init(x: 0, y: y)); minor.addLine(to: .init(x: size.width, y: y)) }
                    }
                    ctx.stroke(minor, with: .color(.cyan.opacity(0.12)), lineWidth: 0.5)
                    ctx.stroke(major, with: .color(.cyan.opacity(0.28)), lineWidth: 0.5)
                    var margins = Path()
                    for gx in [24.0, 56.0, size.width - 24] { margins.move(to: .init(x: gx, y: 0)); margins.addLine(to: .init(x: gx, y: size.height)) }
                    ctx.stroke(margins, with: .color(.red.opacity(0.6)), lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
extension View { func gridOverlay() -> some View { modifier(GridOverlay()) } }

// Same header on every panel: small caption, big title, optional one-liner.
struct PanelHeader: View {
    let caption: String
    let title: String
    var subtitle: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 24, weight: .bold))
            if !subtitle.isEmpty {
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
        }
        .padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 16)   // 32 = traffic-light row + 8
    }
}
