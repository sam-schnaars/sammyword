import SwiftUI
import WebKit

// The engine behind the hosted web games: a WKWebView that loads a game's
// site, runs a small per-game script that spots the finished result, and keeps
// the player on that site. Used by the Sammy Word app (Magnitudle and 100 of
// Us, with their ads) and, in TestFlight builds only, inside Messages.

/// Where the page is in loading.
enum WebLoad: Equatable { case loading, slow, failed, ready }

/// WKWebView wrapper. A per-game script injected before the page loads drives
/// the page (where needed) and reports the finished score exactly once.
struct WebGameWebView: UIViewRepresentable {
    let game: Game
    let reloadToken: Int
    let onLoad: (WebLoad) -> Void
    /// (result, live): `live` is true when the round finished while we watched
    /// (as opposed to opening a day that was already played).
    /// Where links that leave the game's site go (ads, "more games"). The app
    /// opens them in Safari; inside Messages they're simply ignored.
    var onExternalLink: ((URL) -> Void)? = nil
    let onDone: (ScorePayload, Bool) -> Void

    static func url(for game: Game) -> URL {
        game.site ?? URL(string: "about:blank")!
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
        default: return ""
        }
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(game: game, onLoad: onLoad, onDone: onDone)
        c.onExternalLink = onExternalLink
        return c
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: script(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(context.coordinator, name: "scoreDone")
        config.userContentController = controller

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
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

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var onExternalLink: ((URL) -> Void)?
        let game: Game
        var onLoad: (WebLoad) -> Void
        var onDone: (ScorePayload, Bool) -> Void
        var lastToken = 0
        var slowTimer: Timer?

        init(game: Game, onLoad: @escaping (WebLoad) -> Void, onDone: @escaping (ScorePayload, Bool) -> Void) {
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

        /// Keep the player on the game's own site: a tapped ad or outside link
        /// doesn't navigate away (no open web browsing inside the app). Embedded
        /// frames, such as the site's ads, still load inside the page. Links that
        /// ask for a new window already do nothing, since there's no UI delegate.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.targetFrame?.isMainFrame ?? false else { return decisionHandler(.allow) }
            let home = WebGameWebView.url(for: game).host ?? ""
            let site = home.split(separator: ".").suffix(2).joined(separator: ".")
            let host = action.request.url?.host ?? ""
            let scheme = action.request.url?.scheme ?? ""
            let onSite = host == site || host.hasSuffix("." + site)
            if onSite || scheme == "about" || scheme == "blob" || scheme == "data" {
                return decisionHandler(.allow)
            }
            if let url = action.request.url, scheme == "https" || scheme == "http" { onExternalLink?(url) }
            decisionHandler(.cancel)
        }

        /// Links that ask for a new window (most ad clicks): hand them to Safari
        /// when the app allows it; never open a second web view.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, ["http", "https"].contains(url.scheme ?? "") { onExternalLink?(url) }
            return nil
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
            let payload = ScorePayload(
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

