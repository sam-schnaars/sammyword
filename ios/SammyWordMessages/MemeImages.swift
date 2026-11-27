import UIKit

/// Today's meme picture, downloaded once from Wikimedia Commons and kept in memory so
/// the caption screen and the chat bubble (`ScoreImageRenderer`) share it.
enum MemeImages {
    private static let cache = NSCache<NSNumber, UIImage>()

    static func image(day: Int) -> UIImage? {
        cache.object(forKey: NSNumber(value: day))
    }

    static func load(day: Int, url: URL) async -> UIImage? {
        if let hit = image(day: day) { return hit }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: NSNumber(value: day))
        return img
    }
}
