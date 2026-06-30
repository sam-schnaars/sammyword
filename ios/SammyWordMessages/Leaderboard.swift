import Foundation

/// Client for the global daily leaderboard — the iOS counterpart to the web's
/// `src/leaderboard.js`. It talks to the same serverless endpoint
/// (`api/leaderboard.js`). The web calls it same-origin; iOS has no origin, so
/// it targets an absolute base URL.
///
/// If the host is unreachable or the backend isn't configured (no Redis), calls
/// resolve to `configured == false` and the UI simply hides the panel — exactly
/// like the web app.
struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let name: String
    let score: Int
    let you: Bool
}

struct LeaderboardData {
    let configured: Bool
    let entries: [LeaderboardEntry]
    let rank: Int?

    static let unavailable = LeaderboardData(configured: false, entries: [], rank: nil)
}

enum Leaderboard {
    /// The deployed web host that serves `/api/leaderboard`. Point this at the
    /// Vercel deployment (see PARITY.md → Known gaps).
    static let base = "https://sammyword.app"

    static func fetch(day: String) async -> LeaderboardData {
        guard var comps = URLComponents(string: "\(base)/api/leaderboard") else {
            return .unavailable
        }
        comps.queryItems = [
            URLQueryItem(name: "day", value: day),
            URLQueryItem(name: "clientId", value: DailyStore.clientId),
        ]
        guard let url = comps.url else { return .unavailable }
        return await request(URLRequest(url: url))
    }

    static func submit(day: String, score: Int, name: String) async -> LeaderboardData {
        guard let url = URL(string: "\(base)/api/leaderboard") else { return .unavailable }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "day": day,
            "score": score,
            "name": name,
            "clientId": DailyStore.clientId,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return await request(req)
    }

    // MARK: - Private

    private struct APIResponse: Decodable {
        let configured: Bool?
        let entries: [APIEntry]?
        let rank: Int?
    }
    private struct APIEntry: Decodable {
        let name: String
        let score: Int
        let you: Bool?
    }

    private static func request(_ req: URLRequest) async -> LeaderboardData {
        do {
            var r = req
            r.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: r)
            let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
            guard decoded.configured == true else { return .unavailable }
            let entries = (decoded.entries ?? []).map {
                LeaderboardEntry(name: $0.name, score: $0.score, you: $0.you ?? false)
            }
            return LeaderboardData(configured: true, entries: entries, rank: decoded.rank)
        } catch {
            return .unavailable
        }
    }
}
