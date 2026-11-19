import SwiftUI
import WebKit

/// A daily web game (Krillion, Magnitudle, 100 of Us, Eraly) played inside Messages. We don't
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
        session.sendNow(payload) { failure in
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
        case .magnitudle: return URL(string: "https://magnitudle.com/daily")!
        case .hundredOfUs: return URL(string: "https://logicers.com/100-of-us/")!
        case .eraly: return URL(string: "https://eraly.io/")!
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

    /// Magnitudle's daily question keeps the result on its server, not in
    /// localStorage, so we read the result screen ("ACTUAL ANSWER", "92 /100").
    /// Seeing the estimate box first means the guess happened in front of us.
    private static let magnitudle = """
    (function () {
    \(post)
      var sawInput = false, reported = false, last = null, still = 0;
      setInterval(function () {
        if (!/^\\/daily/.test(location.pathname)) return;
        if (document.querySelector('input[placeholder*="estimate" i]')) sawInput = true;
        if (reported) return;
        var text = document.body ? document.body.innerText : '';
        if (!/ACTUAL ANSWER/i.test(text)) return;
        var m = /(\\d+)\\s*\\/\\s*100\\b/.exec(text);
        if (!m) return;
        // The score counts up and eases out slowly near the end; only trust it
        // once it has held still for two seconds.
        if (last !== m[1]) { last = m[1]; still = 0; return; }
        if (++still < 4) return;
        reported = true;
        var d = /Daily Question\\s*#(\\d+)/i.exec(text);
        post(d ? Number(d[1]) : null, Number(m[1]), [], sawInput);
      }, 500);
    })();
    """

    /// 100 of Us files each day's guess and answer in `turnsout:v1` under the
    /// day number; we report once "Turns out, about N." is on screen. The
    /// headline is how far off the guess was.
    private static let hundredOfUs = """
    (function () {
    \(post)
      var results = function () {
        var s = json('turnsout:v1');
        return (s && s.games && s.games['100-of-us'] && s.games['100-of-us'].results) || {};
      };
      var before = null, reported = false;
      setInterval(function () {
        var r = results();
        if (before === null) { before = {}; for (var k in r) before[k] = true; }
        if (reported) return;
        var text = document.body ? document.body.innerText : '';
        var m = /100 of Us\\s*Day\\s*(\\d+)/i.exec(text);
        var e = m && r[m[1]];
        if (!e || e.g == null || e.a == null || !/Turns out/i.test(text)) return;
        reported = true;
        var g = Math.round(Number(e.g)), a = Math.round(Number(e.a));
        post(Number(m[1]), Math.abs(g - a), [String(g), String(a)], !before[m[1]]);
      }, 500);
    })();
    """

    /// Eraly: press "Start the journey" so the first moment comes up at once.
    /// A finished day is saved as `eraly:result:<day>` with a `total` and each
    /// round's points; we report once the "N/700" results screen shows.
    private static let eraly = """
    (function () {
    \(post)
      var latest = function () {
        var best = null;
        for (var i = 0; i < localStorage.length; i++) {
          var m = /^eraly:result:(\\d+)$/.exec(localStorage.key(i) || '');
          if (m && (best === null || Number(m[1]) > best)) best = Number(m[1]);
        }
        return best;
      };
      var before = null, started = false, reported = false;
      setInterval(function () {
        if (location.pathname !== '/') return;
        var day = latest();
        if (before === null) before = day === null ? -1 : day;
        if (!started) {
          var els = document.querySelectorAll('button');
          for (var i = 0; i < els.length; i++) {
            // The page keeps hidden copies of its buttons; only press a visible one.
            if (els[i].offsetParent && /start the journey/i.test(els[i].innerText || '')) {
              started = true; els[i].click(); break;
            }
          }
        }
        if (reported || day === null) return;
        var text = document.body ? document.body.innerText : '';
        if (!/\\d+\\s*\\/\\s*700/.test(text)) return;   // wait for the results screen
        var r = json('eraly:result:' + day);
        if (!r) return;
        reported = true;
        var marks = (r.results || []).map(function (x) { return String(Math.round(Number(x.pts) || 0)); });
        var total = r.total != null ? Number(r.total)
          : marks.reduce(function (a, b) { return a + Number(b); }, 0);
        post(day, Math.round(total) || 0, marks, day !== before);
      }, 500);
    })();
    """

    private func script() -> String {
        switch game {
        case .krillion: return Self.krillion
        case .magnitudle: return Self.magnitudle
        case .hundredOfUs: return Self.hundredOfUs
        case .eraly: return Self.eraly
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
