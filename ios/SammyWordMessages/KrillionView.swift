import SwiftUI
import WebKit

/// Krillion (krillion.io, an indie daily rare-answer game) played inside
/// Messages. We don't reimplement it: the real site runs in a web view, and its
/// own "share results" button is intercepted and turned into an iMessage bubble
/// so friends can trade results back and forth.
///
/// Like `MessagesViewController`, this is platform glue (WebKit), not game logic.
struct KrillionView: View {
    let incoming: KrillionPayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @State private var showFriend = true
    @State private var lastShared: String?

    static let home = URL(string: "https://krillion.io/")!

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onHome) {
                    Label("Games", systemImage: "chevron.left")
                        .font(Theme.rounded(15, .semibold))
                }
                .foregroundColor(Theme.headerText)
                Spacer()
                Text("🦐 Krillion").font(Theme.rounded(17, .heavy)).foregroundColor(Theme.headerText)
                Spacer()
                Button { stage(text: lastShared) } label: {
                    Label("Send", systemImage: "paperplane.fill")
                        .font(Theme.rounded(15, .bold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.accent, in: Capsule())
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if let friend = incoming, let text = friend.shareText, !text.isEmpty, showFriend {
                friendCard(name: friend.senderName, text: text)
            }

            KrillionWebView(url: Self.home) { text in
                // The site's Share / Copy button fired: stage their result as a bubble.
                lastShared = text
                stage(text: text)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func friendCard(name: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(name ?? "A friend")'s dive")
                    .font(Theme.rounded(13, .bold)).foregroundColor(Theme.mutedText)
                Spacer()
                Button { withAnimation { showFriend = false } } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Theme.dimText)
            }
            Text(text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Theme.onBackground)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(8)
        }
        .padding(12)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.panelBorder, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func stage(text: String?) {
        let name = DailyStore.playerName.trimmingCharacters(in: .whitespaces)
        let payload = KrillionPayload(shareText: text, senderName: name.isEmpty ? nil : name)
        session.send(.krillion(payload), payload.caption, true)
    }
}

/// WKWebView wrapper. A script injected before the page loads replaces
/// `navigator.share` and `navigator.clipboard.writeText` so the site's share
/// text comes back to Swift instead of opening the system share sheet.
struct KrillionWebView: UIViewRepresentable {
    let url: URL
    let onShare: (String) -> Void

    private static let bridge = """
    (function () {
      var post = function (t) {
        try { window.webkit.messageHandlers.krillionShare.postMessage(String(t || '')); } catch (e) {}
      };
      var share = function (d) {
        d = d || {};
        var parts = [d.title, d.text, d.url].filter(function (x) { return x; });
        post(parts.join('\\n'));
        return Promise.resolve();
      };
      try { Object.defineProperty(navigator, 'share', { value: share, configurable: true }); } catch (e) {}
      try { Object.defineProperty(navigator, 'canShare', { value: function () { return true; }, configurable: true }); } catch (e) {}
      var clip = navigator.clipboard;
      var orig = clip && clip.writeText ? clip.writeText.bind(clip) : null;
      var write = function (t) {
        post(t);
        return orig ? orig(t).catch(function () {}) : Promise.resolve();
      };
      try {
        if (clip) Object.defineProperty(clip, 'writeText', { value: write, configurable: true });
        else Object.defineProperty(navigator, 'clipboard', { value: { writeText: write }, configurable: true });
      } catch (e) {}
    })();
    """

    func makeCoordinator() -> Coordinator { Coordinator(onShare: onShare) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: "krillionShare")
        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.onShare = onShare
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "krillionShare")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onShare: (String) -> Void
        init(onShare: @escaping (String) -> Void) { self.onShare = onShare }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let text = message.body as? String else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            DispatchQueue.main.async { self.onShare(trimmed) }
        }
    }
}
