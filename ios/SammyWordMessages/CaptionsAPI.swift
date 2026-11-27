import Foundation

/// One caption on today's board.
struct CaptionEntry: Decodable, Identifiable, Equatable {
    let id: String
    let text: String
    let name: String?
    let author: String      // stable per-device hash, used to hide someone locally
    let votes: Int
    let mine: Bool
}

/// Today's picture, chosen by the server (`api/_memes.js`) and loaded from
/// Wikimedia Commons (public-domain paintings and NASA photos).
struct MemeInfo: Decodable, Equatable {
    let name: String
    let url: URL
    let width: Double
    let height: Double
}

/// What the board shows this device. Until you've submitted, only `count`.
struct CaptionBoard: Decodable, Equatable {
    let configured: Bool
    var meme: MemeInfo?
    var submitted: Bool?
    var count: Int?
    var mine: String?
    var votedFor: String?
    var captions: [CaptionEntry]?
}

/// Client for the shared caption board (`api/captions.js` on the sammyword
/// Vercel project, stored in its Upstash Redis). No accounts: each device
/// sends a random id kept in `DailyStore.clientId`.
enum CaptionsAPI {
    static let endpoint = URL(string: "https://sammyword.vercel.app/api/captions")!

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func board(day: Int) async throws -> CaptionBoard {
        var c = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "day", value: String(day)),
                        URLQueryItem(name: "clientId", value: DailyStore.clientId)]
        return try await send(URLRequest(url: c.url!))
    }

    static func submit(day: Int, text: String, name: String) async throws -> CaptionBoard {
        try await post(["action": "submit", "day": day, "text": text, "name": name])
    }

    static func vote(day: Int, id: String) async throws -> CaptionBoard {
        try await post(["action": "vote", "day": day, "id": id])
    }

    static func report(day: Int, id: String) async throws -> CaptionBoard {
        try await post(["action": "report", "day": day, "id": id])
    }

    private static func post(_ body: [String: Any]) async throws -> CaptionBoard {
        var all = body
        all["clientId"] = DailyStore.clientId
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: all)
        return try await send(req)
    }

    private struct ErrorBody: Decodable { let error: String?; let message: String? }

    private static func send(_ request: URLRequest) async throws -> CaptionBoard {
        var req = request
        req.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let e = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw Failure(message: e?.message ?? friendly(e?.error, status: status))
        }
        return try JSONDecoder().decode(CaptionBoard.self, from: data)
    }

    private static func friendly(_ code: String?, status: Int) -> String {
        switch code {
        case "already submitted": return "You've already captioned today's meme."
        case "already voted": return "You've already voted today."
        case "can't vote for your own": return "You can't vote for your own caption."
        case "slow down", "too many votes from this network": return "Slow down a little and try again."
        case "that meme is closed": return "That meme is closed. Try today's."
        default: return "Couldn't reach the caption board (\(status))."
        }
    }
}
