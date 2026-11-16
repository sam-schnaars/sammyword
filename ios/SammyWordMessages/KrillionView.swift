import SwiftUI
import WebKit

/// Krillion (krillion.io, an indie daily rare-answer game) played inside
/// Messages. We don't reimplement it: the real site runs in a web view. To keep
/// friction near zero the page is driven for the player — the dive starts on its
/// own, and the moment it finishes the score goes out as a bubble.
///
/// Like `MessagesViewController`, this is platform glue (WebKit), not game logic.
struct KrillionView: View {
    let incoming: KrillionPayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    /// Today's finished result, once the page reports one.
    @State private var result: KrillionPayload?
    @State private var status: SendStatus = .idle

    private enum SendStatus: Equatable {
        case idle, sending, sent
        case staged(String)   // Messages refused; bubble is waiting in the input field
    }

    static let home = URL(string: "https://krillion.io/")!

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onHome) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Theme.mutedText)

                if let friend = incoming, let score = friend.score {
                    Text("🦐 \(friend.senderName ?? "Friend"): \(score)")
                        .font(Theme.rounded(14, .bold))
                        .foregroundColor(Theme.headerText)
                        .lineLimit(1)
                } else {
                    Text("🦐 Krillion").font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
                }
                Spacer()
                if let result {
                    Button { deliver(result) } label: {
                        Text(pillText(result))
                            .font(Theme.rounded(13, .bold))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(status == .sent ? Theme.panel : Theme.accent, in: Capsule())
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)

            KrillionWebView(url: Self.home) { finished, live in
                var mine = finished
                let name = DailyStore.playerName.trimmingCharacters(in: .whitespaces)
                mine.senderName = name.isEmpty ? nil : name
                result = mine
                // Just finished a dive in front of us → send it without asking.
                if live { deliver(mine) }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func pillText(_ result: KrillionPayload) -> String {
        switch status {
        case .idle: return "Send \(result.score ?? 0)"
        case .sending: return "Sending…"
        case .sent: return "Sent ✓"
        case let .staged(why): return "Tap ↑ to send (\(why))"
        }
    }

    private func deliver(_ payload: KrillionPayload) {
        guard status != .sending else { return }
        status = .sending
        session.sendNow(.krillion(payload), payload.caption) { failure in
            status = failure.map { .staged($0) } ?? .sent
        }
    }
}

/// WKWebView wrapper. A script injected before the page loads:
///  - presses the site's "begin" button so the questions start immediately, and
///  - watches the site's saved game state and reports the finished score once.
struct KrillionWebView: UIViewRepresentable {
    let url: URL
    /// (result, live) — `live` is true when the dive finished while we watched
    /// (as opposed to opening a day that was already played).
    let onDone: (KrillionPayload, Bool) -> Void

    private static let bridge = """
    (function () {
      var json = function (key) {
        try { return JSON.parse(localStorage.getItem(key) || 'null'); } catch (e) { return null; }
      };
      // Krillion keeps the dive in progress under one key and, once it ends,
      // clears that and files the result under its stats history by date.
      var history = function () { var s = json('krillion:stats:v1'); return (s && s.history) || {}; };
      var before = null, started = false, reported = false, liveDate = null;
      setInterval(function () {
        if (location.pathname !== '/') return;
        var h = history();
        if (before === null) { before = {}; for (var k in h) before[k] = true; }
        var g = json('krillion:game:v1');
        if (g && g.phase === 'intro' && !started) {
          var els = document.querySelectorAll('button, a');
          for (var i = 0; i < els.length; i++) {
            if (/begin descent/i.test(els[i].innerText || '')) { started = true; els[i].click(); break; }
          }
        }
        if (g && g.date && g.phase && g.phase !== 'intro') liveDate = g.date;
        if (reported) return;
        var date = liveDate, live = true;
        if (!date || !h[date] || before[date]) {
          // Nothing finished while we watched. If the page is showing a finished
          // day ("DIVE #123 COMPLETE"), report that day's saved result once.
          if (g && g.phase && g.phase !== 'done') return;
          var m = /DIVE\\s*#(\\d+)\\s*COMPLETE/i.exec(document.body ? document.body.innerText : '');
          if (!m) return;
          date = null;
          for (var d in h) { if (String(h[d].dayNumber) === m[1]) date = d; }
          if (!date) return;
          live = false;
        }
        var entry = h[date];
        reported = true;
        var tiers = (entry.tiers || []).map(function (t) { return String(t || 'miss'); });
        try {
          window.webkit.messageHandlers.krillionDone.postMessage(
            JSON.stringify({ day: entry.dayNumber, score: Number(entry.score) || 0, tiers: tiers, live: live }));
        } catch (e) {}
      }, 400);
    })();
    """

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: "krillionDone")
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
        context.coordinator.onDone = onDone
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "krillionDone")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onDone: (KrillionPayload, Bool) -> Void
        init(onDone: @escaping (KrillionPayload, Bool) -> Void) { self.onDone = onDone }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let text = message.body as? String,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let score = json["score"] as? Int
            else { return }
            let payload = KrillionPayload(
                score: score,
                day: json["day"] as? Int,
                tiers: json["tiers"] as? [String] ?? []
            )
            let live = json["live"] as? Bool ?? false
            DispatchQueue.main.async { self.onDone(payload, live) }
        }
    }
}
