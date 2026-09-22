import AppKit
import SwiftUI

// A mockup (or anything else) a skill wants a human verdict on. One JSON
// file per item in ~/piroba/reviews; skills write the item, this panel
// writes the verdict back into the same file.
struct ReviewItem: Identifiable, Codable {
    var id: String
    var feature: Int?
    var title: String
    var stage: String            // wireframe | hifi | …
    var url: String
    var questions: [String] = []
    var status: String = "pending"   // pending | approved | changes | sent
    var comment: String = ""
    var reviewer: String = ""
    var created: String = ""
    var updated: String = ""
}

@MainActor
final class ReviewsStore: ObservableObject {
    @Published var items: [ReviewItem] = []
    let dir = Settings.root.appendingPathComponent("reviews")
    var waiting: Int { items.filter { $0.status == "pending" }.count }

    init() { load() }

    func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        items = files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(ReviewItem.self, from: data)
        }.sorted { ($0.status == "pending" ? 0 : 1, $0.updated) < ($1.status == "pending" ? 0 : 1, $1.updated) }
    }

    func set(_ item: ReviewItem, status: String, comment: String? = nil, reviewer: String? = nil) {
        var it = item
        it.status = status
        if let comment { it.comment = comment }
        if let reviewer { it.reviewer = reviewer }
        it.updated = ISO8601DateFormatter().string(from: Date())
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(it) { try? data.write(to: dir.appendingPathComponent("\(it.id).json")) }
        load()
    }
}

final class ReviewsPanel: NSPanel {
    init(store: ReviewsStore) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
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
        let host = NSHostingView(rootView: ReviewsView(store: store))
        contentView = host
        setContentSize(host.fittingSize)
        setFrameAutosaveName("reviews")
        if frame.origin == .zero, let f = NSScreen.main?.visibleFrame {
            setFrameOrigin(NSPoint(x: f.maxX - frame.width - 24, y: f.maxY - frame.height - 60))
        }
    }
}

struct ReviewsView: View {
    @ObservedObject var store: ReviewsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.waiting == 0 ? "Nothing waiting" : "\(store.waiting) waiting for you").font(.caption).foregroundStyle(.secondary)
                Text("Reviews").font(.title2.weight(.semibold))
            }
            .padding(.horizontal, 22).padding(.top, 26).padding(.bottom, 10)

            if store.items.isEmpty {
                Text("Skills queue mockups here with /mockup.").font(.callout).foregroundStyle(.tertiary)
                    .padding(.horizontal, 22).padding(.bottom, 22)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.items) { item in ReviewRow(item: item, store: store) }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
                .frame(maxHeight: 520)
            }
        }
        .frame(width: 420)
        .background(.regularMaterial)
    }
}

struct ReviewRow: View {
    let item: ReviewItem
    @ObservedObject var store: ReviewsStore
    @State private var comment = ""
    @State private var reviewer = ""
    @State private var mode = ""     // "" | changes | send

    private var pending: Bool { item.status == "pending" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon).font(.caption).foregroundStyle(tint).frame(width: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.body).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(item.stage.uppercased()).font(.system(size: 9, weight: .semibold)).kerning(0.5)
                            .padding(.horizontal, 5).padding(.vertical, 1.5).background(.quaternary, in: Capsule())
                        if let f = item.feature { Text("#" + String(f)).font(.caption) }
                        if !pending { Text(statusLine).font(.caption) }
                    }
                    .foregroundStyle(.secondary)
                    ForEach(item.questions, id: \.self) { q in
                        Text("· \(q)").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Button("Open") { if let u = URL(string: item.url) { NSWorkspace.shared.open(u) } }
                    .controlSize(.mini)
            }
            if pending {
                HStack(spacing: 8) {
                    Button("Approve") { store.set(item, status: "approved") }.controlSize(.small).keyboardShortcut(.defaultAction)
                    Button("Changes…") { mode = mode == "changes" ? "" : "changes" }.controlSize(.small)
                    Button("Send to…") { mode = mode == "send" ? "" : "send" }.controlSize(.small)
                }
                .padding(.leading, 24)
                if mode == "changes" {
                    HStack {
                        TextField("What should change?", text: $comment).textFieldStyle(.roundedBorder).controlSize(.small)
                        Button("Send back") { store.set(item, status: "changes", comment: comment); mode = "" }
                            .controlSize(.small).disabled(comment.isEmpty)
                    }
                    .padding(.leading, 24)
                }
                if mode == "send" {
                    HStack {
                        TextField("Reviewer, e.g. Alex (aviation broking)", text: $reviewer).textFieldStyle(.roundedBorder).controlSize(.small)
                        Button("Copy link & mark sent") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.url, forType: .string)
                            store.set(item, status: "sent", reviewer: reviewer); mode = ""
                        }
                        .controlSize(.small).disabled(reviewer.isEmpty)
                    }
                    .padding(.leading, 24)
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(pending ? Color.primary.opacity(0.03) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch item.status {
        case "approved": "checkmark.circle.fill"
        case "changes": "arrow.uturn.backward.circle"
        case "sent": "paperplane.fill"
        default: "eye"
        }
    }
    private var tint: Color { item.status == "approved" ? .green : item.status == "changes" ? .orange : .secondary }
    private var statusLine: String {
        switch item.status {
        case "sent": "with \(item.reviewer)"
        case "changes": "sent back: \(item.comment)"
        default: item.status
        }
    }
}
