import SwiftUI

/// Doodle: pick one of three secret words, draw it on a 12×12 grid and send it.
/// Friends tap the bubble, see the drawing and get six guesses, with letters
/// filling in as hints. Guess it (or give up) and it's your turn to draw.
struct DoodleView: View {
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    enum Mode: Equatable {
        case pick
        case draw(word: Int)
        case waiting(word: String)          // your own doodle, sent
        case guess(word: String, drawing: [Int], artist: String)
        case result(word: String, tries: Int, drawing: [Int])
    }

    @State private var mode: Mode = .pick
    @State private var choices = Doodle.choices()
    @State private var cells = Doodle.blank
    @State private var color = 1
    @State private var fill = false
    @State private var guess = ""
    @State private var misses: [String] = []
    @State private var status: SendStatus = .idle
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(game: .doodle, onHome: onHome)
            ScrollView {
                VStack(spacing: 16) {
                    switch mode {
                    case .pick: pick
                    case let .draw(word): draw(word)
                    case let .waiting(word): waiting(word)
                    case let .guess(word, drawing, artist): guessing(word, drawing, artist)
                    case let .result(word, tries, drawing): result(word, tries, drawing)
                    }
                }
                .padding(18)
            }
            .scrollDisabled(isDrawing)
        }
        .onAppear(perform: begin)
    }

    private var isDrawing: Bool {
        if case .draw = mode { return true }
        return false
    }

    /// A friend's doodle opens straight into guessing; your own shows the word.
    private func begin() {
        guard !started else { return }
        started = true
        guard let p = incoming, p.isDoodlePrompt, let drawing = p.drawing,
              let word = Doodle.word(forSecret: p.secret) else { return }
        if session.incomingIsMine {
            mode = .waiting(word: word)
        } else {
            mode = .guess(word: word, drawing: Doodle.decode(drawing), artist: p.senderName ?? "Your friend")
        }
    }

    // MARK: Pick

    private var pick: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                PixelSprite(art: Game.doodle.sprite, scale: 6)
                PixelText("PICK A SECRET WORD", scale: 2.5)
                Text("Draw it in pixels and send it. Your friends get \(Doodle.maxGuesses) guesses.")
                    .font(Pixel.mono(13))
                    .foregroundColor(Pixel.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .pixelBox(Pixel.panel, step: 4)

            ForEach(choices, id: \.self) { i in
                PixelActionButton(title: Doodle.words[i], palette: Pixel.row) {
                    cells = Doodle.blank
                    color = 1
                    fill = false
                    status = .idle
                    mode = .draw(word: i)
                }
            }
            PixelActionButton(title: "NEW WORDS", palette: Pixel.panel, scale: 2) {
                choices = Doodle.choices()
            }
        }
    }

    // MARK: Draw

    private func draw(_ word: Int) -> some View {
        VStack(spacing: 14) {
            HStack {
                PixelText("DRAW:", scale: 2, color: Pixel.muted, shadow: nil)
                PixelText(Doodle.words[word], scale: 2.5, color: Pixel.gold)
                Spacer()
            }
            DoodleCanvas(cells: $cells, color: color, fill: fill, editable: true)
            palette
            HStack(spacing: 10) {
                toolButton(fill ? "FILL" : "PEN") { fill.toggle() }
                toolButton("ERASE", active: color == 0) { color = 0 }
                toolButton("CLEAR") { cells = Doodle.blank }
            }
            NameField()
            PixelActionButton(title: "SEND DOODLE") {
                let payload = ScorePayload(game: .doodle, drawing: Doodle.encode(cells),
                                           secret: Doodle.scramble(word))
                Delivery.send(payload, session: session, status: $status)
                mode = .waiting(word: Doodle.words[word])
            }
            .disabled(!cells.contains { $0 != 0 })
            .opacity(cells.contains { $0 != 0 } ? 1 : 0.5)
        }
    }

    private var palette: some View {
        HStack(spacing: 6) {
            ForEach(1..<Doodle.palette.count, id: \.self) { i in
                Button { color = i } label: {
                    Rectangle()
                        .fill(Color(hex: Doodle.palette[i]))
                        .frame(height: 30)
                        .overlay(Rectangle().stroke(color == i ? Pixel.cream : Pixel.ink, lineWidth: color == i ? 3 : 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toolButton(_ title: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelText(title, scale: 2, color: active ? Pixel.gold : Pixel.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(PixelButtonStyle(palette: Pixel.row, step: 2))
    }

    // MARK: Waiting (your own doodle)

    private func waiting(_ word: String) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                PixelText(status == .staged ? "READY TO SEND" : status == .sent ? "DOODLE SENT" : "SENDING...", scale: 3, color: Pixel.green)
                Text(status == .staged
                     ? "It's waiting in the text field. Tap the send arrow."
                     : "Now see who guesses it. The word was:")
                    .font(Pixel.mono(13))
                    .foregroundColor(Pixel.muted)
                    .multilineTextAlignment(.center)
                PixelText(word, scale: 4, color: Pixel.gold)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .pixelBox(Pixel.panel, step: 4)
            PixelActionButton(title: "DRAW ANOTHER", palette: Pixel.row) {
                choices = Doodle.choices()
                mode = .pick
            }
        }
    }

    // MARK: Guess

    private func guessing(_ word: String, _ drawing: [Int], _ artist: String) -> some View {
        VStack(spacing: 14) {
            Text("\(artist) drew something. What is it?")
                .font(Pixel.mono(14, .bold))
                .foregroundColor(Pixel.cream)
            DoodleCanvas(cells: .constant(drawing), color: 0, fill: false, editable: false)
            PixelText(Doodle.hint(for: word, misses: misses.count), scale: 3, color: Pixel.gold)
            PixelText("\(Doodle.maxGuesses - misses.count) GUESSES LEFT", scale: 1.5, color: Pixel.muted, shadow: nil)
            HStack(spacing: 10) {
                TextField("", text: $guess, prompt: Text("Your guess").foregroundColor(Pixel.muted.opacity(0.6)))
                    .font(Pixel.mono(17, .bold))
                    .foregroundColor(Pixel.cream)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { submit(word, drawing) }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .pixelBox(Pixel.row, step: 2)
                Button { submit(word, drawing) } label: {
                    PixelText("GUESS", scale: 2).padding(.horizontal, 10).padding(.vertical, 10)
                }
                .buttonStyle(PixelButtonStyle(step: 3))
            }
            if !misses.isEmpty {
                Text(misses.map { "✗ \($0)" }.joined(separator: "   "))
                    .font(Pixel.mono(13, .bold))
                    .foregroundColor(Color(hex: 0xF07A84))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { reveal(word, tries: 0, drawing) } label: {
                Text("Give up").font(Pixel.mono(13)).foregroundColor(Pixel.muted).underline()
            }
        }
    }

    private func submit(_ word: String, _ drawing: [Int]) {
        let g = guess.trimmingCharacters(in: .whitespaces)
        guard !g.isEmpty else { return }
        guess = ""
        if Doodle.matches(g, word) {
            reveal(word, tries: misses.count + 1, drawing)
        } else {
            misses.append(g.lowercased())
            if misses.count >= Doodle.maxGuesses { reveal(word, tries: 0, drawing) }
        }
    }

    /// Show the answer and post how it went to the chat.
    private func reveal(_ word: String, tries: Int, _ drawing: [Int]) {
        mode = .result(word: word, tries: tries, drawing: drawing)
        let payload = ScorePayload(game: .doodle, score: tries, marks: [word], drawing: Doodle.encode(drawing))
        Delivery.send(payload, session: session, status: $status)
    }

    // MARK: Result

    private func result(_ word: String, _ tries: Int, _ drawing: [Int]) -> some View {
        VStack(spacing: 16) {
            ScoreCard(title: tries == 0 ? "SO CLOSE" : "GOT IT!",
                      value: word.uppercased(),
                      detail: tries == 0 ? "Better luck next doodle." : "in \(tries) \(tries == 1 ? "guess" : "guesses")")
            if status == .staged {
                Text("Your result is waiting in the text field. Tap the send arrow.")
                    .font(Pixel.mono(12)).foregroundColor(Pixel.muted)
            }
            PixelActionButton(title: "YOUR TURN TO DRAW") {
                choices = Doodle.choices()
                misses = []
                mode = .pick
            }
        }
    }
}

/// The 12×12 drawing grid. When editable, dragging paints cells (or flood-fills
/// with the fill tool).
struct DoodleCanvas: View {
    @Binding var cells: [Int]
    let color: Int
    let fill: Bool
    let editable: Bool
    /// The last cell painted in this stroke, so fast drags leave no gaps.
    @State private var last: (r: Int, c: Int)?

    var body: some View {
        GeometryReader { geo in
            let n = Doodle.size
            let side = min(geo.size.width, geo.size.height)
            let cell = (side / CGFloat(n)).rounded(.down)
            let origin = CGPoint(x: (geo.size.width - cell * CGFloat(n)) / 2,
                                 y: (geo.size.height - cell * CGFloat(n)) / 2)
            Canvas { ctx, _ in
                for i in 0..<(n * n) {
                    let r = CGRect(x: origin.x + CGFloat(i % n) * cell, y: origin.y + CGFloat(i / n) * cell,
                                   width: cell, height: cell)
                    ctx.fill(Path(r), with: .color(Color(hex: Doodle.palette[cells[i]])))
                }
                if editable {
                    var grid = Path()
                    for k in 1..<n {
                        let o = CGFloat(k) * cell
                        grid.addRect(CGRect(x: origin.x + o, y: origin.y, width: 0.5, height: cell * CGFloat(n)))
                        grid.addRect(CGRect(x: origin.x, y: origin.y + o, width: cell * CGFloat(n), height: 0.5))
                    }
                    ctx.fill(grid, with: .color(.black.opacity(0.12)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard editable else { return }
                        let c = Int(((v.location.x - origin.x) / cell).rounded(.down))
                        let r = Int(((v.location.y - origin.y) / cell).rounded(.down))
                        guard r >= 0, r < n, c >= 0, c < n else { return }
                        if fill {
                            flood(from: r * n + c)
                        } else {
                            paintLine(from: last ?? (r, c), to: (r, c))
                        }
                        last = (r, c)
                    }
                    .onEnded { _ in last = nil }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .pixelBox(Pixel.panel, step: 4)
    }

    /// Paint every cell on the straight line between two cells.
    private func paintLine(from a: (r: Int, c: Int), to b: (r: Int, c: Int)) {
        let steps = max(abs(b.r - a.r), abs(b.c - a.c), 1)
        var out = cells
        for k in 0...steps {
            let t = Double(k) / Double(steps)
            let r = Int((Double(a.r) + Double(b.r - a.r) * t).rounded())
            let c = Int((Double(a.c) + Double(b.c - a.c) * t).rounded())
            out[r * Doodle.size + c] = color
        }
        if out != cells { cells = out }
    }

    /// Paint-bucket: recolor the connected region of the tapped cell's color.
    private func flood(from start: Int) {
        let target = cells[start]
        guard target != color else { return }
        let n = Doodle.size
        var stack = [start]
        var out = cells
        while let i = stack.popLast() {
            guard out[i] == target else { continue }
            out[i] = color
            let r = i / n, c = i % n
            if r > 0 { stack.append(i - n) }
            if r < n - 1 { stack.append(i + n) }
            if c > 0 { stack.append(i - 1) }
            if c < n - 1 { stack.append(i + 1) }
        }
        cells = out
    }
}
