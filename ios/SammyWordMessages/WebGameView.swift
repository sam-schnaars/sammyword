import SwiftUI
import WebKit

/// A daily web game (Krillion, Size It Up) played inside Messages. We don't
/// reimplement them: the real site runs in a web view. To keep friction near
/// zero the page is driven for the player where the site allows it, and the
/// moment a round finishes the score goes out as a bubble.
///
/// Like `MessagesViewController`, this is platform glue (WebKit), not game logic.
struct WebGameView: View {
    let game: WebGame
    /// A friend's result for this same game, when opened from their bubble.
    let incoming: WebScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    /// Today's finished result, once the page reports one.
    @State private var result: WebScorePayload?
    @State private var status: SendStatus = .idle
    @State private var load: WebLoad = .loading
    @State private var reloadToken = 0

    private enum SendStatus: Equatable {
        case idle, sending, sent
        case staged(String)   // Messages refused; bubble is waiting in the input field
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onHome) {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Theme.mutedText)

                if let friend = incoming, friend.score != nil {
                    Text("\(game.emoji) \(friend.senderName ?? "Friend"): \(friend.scoreText)")
                        .font(Theme.rounded(14, .bold))
                        .foregroundColor(Theme.headerText)
                        .lineLimit(1)
                } else {
                    Text("\(game.emoji) \(game.title)").font(Theme.rounded(14, .bold)).foregroundColor(Theme.headerText)
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

            ZStack {
                WebGameWebView(game: game, reloadToken: reloadToken, onLoad: { load = $0 }) { finished, live in
                    var mine = finished
                    let name = DailyStore.playerName.trimmingCharacters(in: .whitespaces)
                    mine.senderName = name.isEmpty ? nil : name
                    result = mine
                    // Just finished a round in front of us → send it without asking.
                    if live { deliver(mine) }
                }
                if load != .ready { loadingCover }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Covers the page until it has loaded, so a slow site reads as loading
    /// instead of a frozen screen, and offers a way out if it never arrives.
    private var loadingCover: some View {
        VStack(spacing: 14) {
            Text(game.emoji).font(.system(size: 44))
            switch load {
            case .loading:
                ProgressView().tint(Theme.headerText)
                Text("Loading \(game.title)…").font(Theme.rounded(15, .semibold)).foregroundColor(Theme.mutedText)
            case .slow, .failed:
                Text(load == .failed ? "\(game.title) didn't load" : "\(game.title) is taking a while")
                    .font(Theme.rounded(16, .bold)).foregroundColor(Theme.headerText)
                Text("Check your connection, then try again.")
                    .font(Theme.rounded(14, .medium)).foregroundColor(Theme.mutedText)
                Button { load = .loading; reloadToken += 1 } label: {
                    Text("Reload")
                        .font(Theme.rounded(15, .bold)).foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 9)
                        .background(Theme.accent, in: Capsule())
                }
            case .ready:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func pillText(_ result: WebScorePayload) -> String {
        switch status {
        case .idle: return "Send \(result.scoreText)"
        case .sending: return "Sending…"
        case .sent: return "Sent ✓"
        case let .staged(why): return "Tap ↑ to send (\(why))"
        }
    }

    private func deliver(_ payload: WebScorePayload) {
        guard status != .sending else { return }
        status = .sending
        session.sendNow(.web(payload), payload.caption) { failure in
            status = failure.map { .staged($0) } ?? .sent
        }
    }
}

/// Where the page is in loading.
enum WebLoad: Equatable { case loading, slow, failed, ready }

/// WKWebView wrapper. A per-game script injected before the page loads drives
/// the page (where needed) and reports the finished score exactly once.
struct WebGameWebView: UIViewRepresentable {
    let game: WebGame
    let reloadToken: Int
    let onLoad: (WebLoad) -> Void
    /// (result, live): `live` is true when the round finished while we watched
    /// (as opposed to opening a day that was already played).
    let onDone: (WebScorePayload, Bool) -> Void

    static func url(for game: WebGame) -> URL {
        switch game {
        case .krillion: return URL(string: "https://krillion.io/")!
        case .sizeItUp: return URL(string: "https://sizeitup.games/")!
        }
    }

    /// Shared tail: hand the result to Swift.
    private static let post = """
      var post = function (day, score, marks, live) {
        try {
          window.webkit.messageHandlers.scoreDone.postMessage(
            JSON.stringify({ day: day, score: score, marks: marks, live: live }));
        } catch (e) {}
      };
      var json = function (key) {
        try { return JSON.parse(localStorage.getItem(key) || 'null'); } catch (e) { return null; }
      };
    """

    /// Krillion: press "Begin descent" so the questions start at once. The
    /// site keeps the dive in progress under one key and, once it ends, clears
    /// that and files the result under its stats history by date.
    private static let krillion = """
    (function () {
    \(post)
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
        post(entry.dayNumber, Number(entry.score) || 0,
             (entry.tiers || []).map(function (t) { return String(t || 'miss'); }), live);
      }, 400);
    })();
    """

    /// Size It Up opens straight onto the daily, so there is nothing to press.
    /// Each day is saved as `siu:progress:regular:<date>` with five guesses and
    /// round scores; we report once the "Today's five done" results show.
    private static let sizeItUp = """
    (function () {
    \(post)
      var latest = function () {
        var keys = [];
        for (var i = 0; i < localStorage.length; i++) {
          var k = localStorage.key(i);
          if (/^siu:progress:regular:\\d{4}-\\d{2}-\\d{2}$/.test(k)) keys.push(k);
        }
        keys.sort();
        return keys[keys.length - 1] || null;
      };
      var finished = function (p) { return p && (p.guesses || []).length >= 5 && p.lockedAt; };
      var before = null, reported = false;
      setInterval(function () {
        var key = latest(), p = key ? json(key) : null;
        if (before === null) before = finished(p) ? key : '';
        if (reported || !finished(p)) return;
        var text = document.body ? document.body.innerText : '';
        if (!/five done/i.test(text)) return;   // wait for the results screen
        reported = true;
        var m = /No\\.\\s*(\\d+)/.exec(text);
        var rounds = (p.scores || []).map(function (s) { return String(Math.round(Number(s) || 0)); });
        var score = p.bestPoints != null ? p.bestPoints
          : (p.scores || []).reduce(function (a, b) { return a + (Number(b) || 0); }, 0);
        post(m ? Number(m[1]) : null, Math.round(Number(score) || 0), rounds, before !== key);
      }, 500);
    })();
    """

    private func script() -> String {
        switch game {
        case .krillion: return Self.krillion
        case .sizeItUp: return Self.sizeItUp
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(game: game, onLoad: onLoad, onDone: onDone) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: script(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: "scoreDone")
        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        context.coordinator.start(web, url: Self.url(for: game))
        context.coordinator.lastToken = reloadToken
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        context.coordinator.onDone = onDone
        context.coordinator.onLoad = onLoad
        if context.coordinator.lastToken != reloadToken {
            context.coordinator.lastToken = reloadToken
            context.coordinator.start(web, url: Self.url(for: game))
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        coordinator.slowTimer?.invalidate()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "scoreDone")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let game: WebGame
        var onLoad: (WebLoad) -> Void
        var onDone: (WebScorePayload, Bool) -> Void
        var lastToken = 0
        var slowTimer: Timer?

        init(game: WebGame, onLoad: @escaping (WebLoad) -> Void, onDone: @escaping (WebScorePayload, Bool) -> Void) {
            self.game = game
            self.onLoad = onLoad
            self.onDone = onDone
        }

        /// Load the page, and flag it as slow if it hasn't arrived in 15 seconds.
        func start(_ web: WKWebView, url: URL) {
            onLoad(.loading)
            web.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
            slowTimer?.invalidate()
            slowTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
                self?.onLoad(.slow)
            }
        }

        private func finish(_ state: WebLoad) {
            slowTimer?.invalidate()
            DispatchQueue.main.async { self.onLoad(state) }
        }

        // The page is usable once its content has painted; ads may still be loading.
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(.ready) }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Reveal shortly after the first content arrives instead of waiting on every ad.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.finish(.ready) }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failed) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failed) }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // The page's process was killed (usually memory). Reload rather than sit frozen.
            webView.reload()
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let text = message.body as? String,
                  let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let score = json["score"] as? Int
            else { return }
            let payload = WebScorePayload(
                game: game,
                score: score,
                day: json["day"] as? Int,
                marks: json["marks"] as? [String] ?? []
            )
            let live = json["live"] as? Bool ?? false
            DispatchQueue.main.async { self.onDone(payload, live) }
        }
    }
}
