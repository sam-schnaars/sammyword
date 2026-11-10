import SwiftUI

/// HUD + board for an in-progress round.
struct GameView: View {
    @ObservedObject var game: WordHuntGame
    /// A just-scored word, shown briefly as a rising "+points" flourish.
    @State private var flourish: FoundWord?

    var body: some View {
        VStack(spacing: 14) {
            hud
            goals
            wordReadout
            BoardView(game: game)
            Spacer(minLength: 0)
        }
        .padding(20)
        .onChange(of: game.lastScored) { scored in
            guard let scored else { return }
            Haptics.wordScored(length: scored.word.count)
            flourish = scored
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                if flourish?.id == scored.id { flourish = nil }
            }
        }
    }

    private var hud: some View {
        HStack {
            statPill(label: "SCORE", value: String(format: "%04d", game.score))
            Spacer()
            statPill(label: "TIME", value: timeString, low: game.timeRemaining <= 10)
            Spacer()
            statPill(label: "WORDS", value: "\(game.foundWords.count)")
        }
    }

    /// Per-length checklist: how many words of each length exist on the board
    /// vs. how many the player has traced. Scrolls if it overflows the width.
    @ViewBuilder private var goals: some View {
        let lengths = game.possibleByLength.keys.filter { $0 > 3 }.sorted()
        if !lengths.isEmpty {
            HStack(spacing: 6) {
                ForEach(lengths, id: \.self) { len in
                    goalPill(
                        len: len,
                        got: game.foundByLength[len] ?? 0,
                        total: game.possibleByLength[len] ?? 0
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func goalPill(len: Int, got: Int, total: Int) -> some View {
        let done = total > 0 && got >= total
        return VStack(spacing: 1) {
            Text("\(len) LTR")
                .font(Theme.rounded(10, .semibold))
                .foregroundColor(done ? Theme.positiveDim : Theme.dimText)
            Text("\(got)/\(total)")
                .font(Theme.rounded(15, .bold))
                .foregroundColor(done ? Theme.positive : Theme.headerText)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(done ? Theme.positiveBg : Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(done ? Theme.positiveBorder : Theme.panelBorder, lineWidth: 1)
        )
    }

    private func statPill(label: String, value: String, low: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(Theme.rounded(11, .semibold))
                .foregroundColor(Theme.dimText)
            Text(value)
                .font(Theme.rounded(22, .bold))
                .foregroundColor(low ? Theme.lowText : Theme.headerText)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 8)
        .background(low ? Theme.lowBg : Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(low ? Theme.lowBorder : Theme.panelBorder, lineWidth: 1)
        )
    }

    /// Shows the in-progress word (plain / green-valid / amber-duplicate), or a
    /// floating "+points" flourish once a word is scored and the path clears.
    private var wordReadout: some View {
        ZStack {
            if !game.currentWord.isEmpty {
                let valid = game.isCurrentWordValid
                let dupe = game.isCurrentWordDuplicate
                Text(displayWord(game.currentWord))
                    .font(Theme.rounded(22, .heavy))
                    .tracking(3)
                    .foregroundColor(valid ? Theme.validBubbleText : dupe ? Theme.dupeBubbleText : Theme.tileText)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 7)
                    .background(
                        valid ? Theme.validBubbleBg : dupe ? Theme.dupeBubbleBg : Theme.bubbleBg,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            valid ? Theme.validBubbleBorder : dupe ? Theme.dupeBubbleBorder : Theme.panelBorder,
                            lineWidth: 1
                        )
                    )
            } else if let fw = flourish {
                FloatResult(text: "\(displayWord(fw.word)) +\(fw.points)")
                    .id(fw.id)
            }
        }
        .frame(height: 46)
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

/// The "+points" bubble that rises and fades when a word is scored — mirrors the
/// web app's `floatUp` animation.
struct FloatResult: View {
    let text: String
    @State private var lifted = false

    var body: some View {
        Text(text)
            .font(Theme.rounded(22, .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(Theme.selected.opacity(0.7), in: Capsule())
            .offset(y: lifted ? -34 : 8)
            .opacity(lifted ? 0 : 1)
            .onAppear {
                lifted = false
                withAnimation(.easeOut(duration: 0.95)) { lifted = true }
            }
    }
}

/// The 4×4 grid with drag-to-connect selection and the trail line, set inside
/// the web app's framed metal board panel.
struct BoardView: View {
    @ObservedObject var game: WordHuntGame
    private let spacing: CGFloat = 10

    var body: some View {
        let map = game.board.map
        return GeometryReader { geo in
            let L = layout(in: geo.size, map: map)
            let corner = min(geo.size.width, geo.size.height) * 0.085

            ZStack(alignment: .topLeading) {
                TrailShape(path: game.path, layout: L, cols: map.cols)
                    .stroke(
                        Theme.trail,
                        style: StrokeStyle(lineWidth: L.cell * 0.26, lineCap: .round, lineJoin: .round)
                    )

                ForEach(game.board.tiles) { tile in
                    let r = tile.id / map.cols
                    let c = tile.id % map.cols
                    TileView(letter: tile.letter, selected: game.path.contains(tile.id), size: L.cell)
                        .position(
                            x: L.originX + CGFloat(c) * (L.cell + L.spacing) + L.cell / 2,
                            y: L.originY + CGFloat(r) * (L.cell + L.spacing) + L.cell / 2
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Theme.boardPanel, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.boardRim, lineWidth: max(7, corner * 0.33))
            )
            .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard let i = cellIndex(at: value.location, layout: L, map: map) else { return }
                        if game.path.isEmpty {
                            game.beginSelection(at: i)
                        } else {
                            game.extendSelection(to: i)
                        }
                    }
                    .onEnded { _ in game.endSelection() }
            )
        }
        .aspectRatio(CGFloat(map.cols) / CGFloat(map.rows), contentMode: .fit)
    }

    /// Square-cell grid layout for a map, centered in `size`.
    private func layout(in size: CGSize, map: GameMap) -> GridLayout {
        let spacing: CGFloat = map.cols <= 4 ? 10 : 7
        let pad = min(size.width, size.height) * 0.06
        let availW = size.width - pad * 2 - spacing * CGFloat(map.cols - 1)
        let availH = size.height - pad * 2 - spacing * CGFloat(map.rows - 1)
        let cell = max(1, min(availW / CGFloat(map.cols), availH / CGFloat(map.rows)))
        let gridW = cell * CGFloat(map.cols) + spacing * CGFloat(map.cols - 1)
        let gridH = cell * CGFloat(map.rows) + spacing * CGFloat(map.rows - 1)
        return GridLayout(
            cell: cell, spacing: spacing,
            originX: (size.width - gridW) / 2,
            originY: (size.height - gridH) / 2
        )
    }

    /// Maps a touch point to a tile only when it lands near that tile's center.
    /// The gaps between tiles (and holes) are dead zones, so a diagonal drag no
    /// longer clips the orthogonal neighbor on the way to the diagonal one.
    private func cellIndex(at point: CGPoint, layout L: GridLayout, map: GameMap) -> Int? {
        let step = L.cell + L.spacing
        let x = point.x - L.originX
        let y = point.y - L.originY
        let c = Int((x / step).rounded(.down))
        let r = Int((y / step).rounded(.down))
        guard r >= 0, r < map.rows, c >= 0, c < map.cols else { return nil }
        let idx = r * map.cols + c
        guard game.board.isActive(idx) else { return nil }
        let dx = x - (CGFloat(c) * step + L.cell / 2)
        let dy = y - (CGFloat(r) * step + L.cell / 2)
        let hit = L.cell * 0.5          // inscribed circle; tile corners stay dead
        guard dx * dx + dy * dy <= hit * hit else { return nil }
        return idx
    }
}

/// Geometry for laying a map's square cells into a panel.
struct GridLayout {
    let cell: CGFloat
    let spacing: CGFloat
    let originX: CGFloat
    let originY: CGFloat
}

struct TileView: View {
    let letter: String
    let selected: Bool
    let size: CGFloat

    var body: some View {
        let radius = size * 0.18
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(selected ? AnyShapeStyle(Theme.selected) : AnyShapeStyle(Theme.tileGradient))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.selectedRing : Color.white.opacity(0.10),
                        lineWidth: selected ? 2 : 1
                    )
            )
            .overlay(
                Text(letter == "QU" ? "Qu" : letter)
                    .font(Theme.rounded(size * 0.42, .heavy))
                    .foregroundColor(Theme.tileText)
                    .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 1)
            )
            .frame(width: size, height: size)
            .shadow(
                color: selected ? Theme.selected.opacity(0.5) : .black.opacity(0.5),
                radius: selected ? 6 : 3, x: 0, y: 4
            )
            .scaleEffect(selected ? 1.05 : 1)
            .animation(.easeOut(duration: 0.06), value: selected)
    }
}

/// Connects the centers of the selected cells.
struct TrailShape: Shape {
    let path: [Int]
    let layout: GridLayout
    let cols: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = layout.cell + layout.spacing
        for (i, idx) in path.enumerated() {
            let r = idx / cols
            let c = idx % cols
            let pt = CGPoint(
                x: layout.originX + CGFloat(c) * step + layout.cell / 2,
                y: layout.originY + CGFloat(r) * step + layout.cell / 2
            )
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}
