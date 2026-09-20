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
    @Published var items: [ActionItem] { didSet { save() } }
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
        contentView = NSHostingView(rootView: ActionsView(store: store, send: send))
        setFrameAutosaveName("actions")
        if frame.origin == .zero, let f = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: f.maxX - frame.width - 24, y: f.maxY - frame.height - 60))
        }
    }
}

struct ActionsView: View {
    @ObservedObject var store: ActionsStore
    var send: (ActionItem) -> Void
    private var left: Int { store.items.filter { !$0.done }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text("Actions").font(.title2.weight(.semibold))
                if !store.about.isEmpty {
                    Text(store.about).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 14)

            if store.items.isEmpty {
                Text("Nothing to do from this one.").font(.callout).foregroundStyle(.tertiary)
                    .padding(.horizontal, 22).padding(.bottom, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach($store.items) { $item in ActionRow(item: $item, send: { send(item) }) }
                }
                .padding(.horizontal, 12)
            }

            HStack {
                Text(left == 0 ? "All done" : "\(left) left").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Open digest") { NSWorkspace.shared.open(store.dir.appendingPathComponent("digest.md")) }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22).padding(.vertical, 14)
        }
        .frame(width: 380)
        .background(.regularMaterial)
    }

    private var title: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HHmm"
        guard let d = f.date(from: store.dir.lastPathComponent) else { return store.dir.lastPathComponent }
        return d.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).hour().minute())
    }
}

struct ActionRow: View {
    @Binding var item: ActionItem
    var send: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button { withAnimation(.snappy(duration: 0.18)) { item.done.toggle() } } label: {
                ZStack {
                    Circle().strokeBorder(item.done ? Color.accentColor : .secondary.opacity(0.5), lineWidth: 1.5)
                    if item.done {
                        Circle().fill(Color.accentColor)
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.body)
                    .strikethrough(item.done, color: .secondary)
                    .foregroundStyle(item.done ? .tertiary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                if item.ticket {
                    HStack(spacing: 6) {
                        Text("ADO").font(.system(size: 9, weight: .semibold)).kerning(0.5)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(.quaternary, in: Capsule())
                        if !item.detail.isEmpty { Text(item.detail).font(.caption).lineLimit(2) }
                    }
                    .foregroundStyle(item.done ? .quaternary : .secondary)
                }
            }
            Spacer(minLength: 8)

            if item.sent {
                Image(systemName: "paperplane.fill").font(.caption).foregroundStyle(.tertiary).help("Sent to Claude")
            } else if hover && !item.done {
                Button(action: { item.sent = true; send() }) {
                    Image(systemName: "arrow.up.circle.fill").font(.title3).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain).help("Send to Claude Code")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(hover ? Color.primary.opacity(0.04) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}
