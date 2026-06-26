import SwiftUI

/// HUD + board for an in-progress round.
struct GameView: View {
    @ObservedObject var game: WordHuntGame

    var body: some View {
        VStack(spacing: 18) {
            hud
            wordReadout
            BoardView(game: game)
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var hud: some View {
        HStack {
            statPill(label: "SCORE", value: String(format: "%04d", game.score))
            Spacer()
            statPill(label: "TIME", value: timeString)
                .foregroundColor(game.timeRemaining <= 10 ? Color(hex: 0xFFE27A) : Theme.onBackground)
            Spacer()
            statPill(label: "WORDS", value: "\(game.foundWords.count)")
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(Theme.rounded(11, .semibold))
                .opacity(0.85)
            Text(value)
                .font(Theme.rounded(22, .bold))
        }
        .foregroundColor(Theme.onBackground)
        .frame(minWidth: 80)
        .padding(.vertical, 8)
        .background(Theme.pill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var wordReadout: some View {
        ZStack {
            if !game.currentWord.isEmpty {
                Text(displayWord(game.currentWord))
                    .font(Theme.rounded(24, .heavy))
                    .tracking(3)
                    .foregroundColor(game.isCurrentWordValid ? Theme.valid : Theme.letter)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 7)
                    .background(
                        game.isCurrentWordValid ? Color(hex: 0xD9F7C8) : Theme.card,
                        in: Capsule()
                    )
            }
        }
        .frame(height: 44)
        .animation(.easeOut(duration: 0.1), value: game.currentWord)
    }

    private var timeString: String {
        let m = game.timeRemaining / 60
        let s = game.timeRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func displayWord(_ w: String) -> String {
        w.replacingOccurrences(of: "QU", with: "Qu")
    }
}

/// The 4×4 grid with drag-to-connect selection and the trail line.
struct BoardView: View {
    @ObservedObject var game: WordHuntGame
    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - spacing * 3) / 4

            ZStack(alignment: .topLeading) {
                TrailShape(path: game.path, cell: cell, spacing: spacing)
                    .stroke(
                        Theme.trail,
                        style: StrokeStyle(lineWidth: cell * 0.30, lineCap: .round, lineJoin: .round)
                    )

                ForEach(game.board.tiles) { tile in
                    let r = tile.id / 4
                    let c = tile.id % 4
                    TileView(letter: tile.letter, selected: game.path.contains(tile.id), size: cell)
                        .position(
                            x: CGFloat(c) * (cell + spacing) + cell / 2,
                            y: CGFloat(r) * (cell + spacing) + cell / 2
                        )
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let i = cellIndex(at: value.location, cell: cell) else { return }
                        if game.path.isEmpty {
                            game.beginSelection(at: i)
                        } else {
                            game.extendSelection(to: i)
                        }
                    }
                    .onEnded { _ in game.endSelection() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellIndex(at p: CGPoint, cell: CGFloat) -> Int? {
        let step = cell + spacing
        let c = Int(p.x / step)
        let r = Int(p.y / step)
        guard r >= 0, r < 4, c >= 0, c < 4 else { return nil }
        return r * 4 + c
    }
}

struct TileView: View {
    let letter: String
    let selected: Bool
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .fill(selected ? Theme.tileSelected : Theme.tile)
            .frame(width: size, height: size)
            .overlay(
                Text(letter == "QU" ? "Qu" : letter)
                    .font(Theme.rounded(size * 0.42, .heavy))
                    .foregroundColor(Theme.letter)
            )
            .shadow(color: Theme.tileShadow, radius: 0, x: 0, y: 4)
            .scaleEffect(selected ? 1.05 : 1)
            .animation(.easeOut(duration: 0.06), value: selected)
    }
}

/// Connects the centers of the selected cells.
struct TrailShape: Shape {
    let path: [Int]
    let cell: CGFloat
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = cell + spacing
        for (i, idx) in path.enumerated() {
            let r = idx / 4
            let c = idx % 4
            let pt = CGPoint(
                x: CGFloat(c) * step + cell / 2,
                y: CGFloat(r) * step + cell / 2
            )
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}
