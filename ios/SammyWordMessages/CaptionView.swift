import SwiftUI

/// Daily Caption the Meme: today's meme template (the same for everyone). Write a
/// caption and submit it (name optional, anonymous when blank). Once yours is
/// in, everyone else's captions for today show up and you get one vote for the
/// best, never your own. You can also send your caption to the chat as a
/// bubble. Opened from a friend's bubble, their caption shows first.
struct CaptionView: View {
    let incoming: ScorePayload?
    @ObservedObject var session: GameSession
    let onHome: () -> Void

    @State private var text = ""
    @State private var board: CaptionBoard?
    @State private var loading = true
    @State private var busy = false
    @State private var problem: String?
    @State private var muted = DailyStore.mutedAuthors
    @State private var reporting: CaptionEntry?
    @State private var status: SendStatus = .idle
    @State private var picture: UIImage?
    @FocusState private var typing: Bool

    private var day: Int { incoming?.day ?? Daily.number() }
    private var meme: Caption.Meme { Caption.meme(day: day) }
    private var friendCaption: String? { incoming?.captionText }
    private var draft: String { Caption.clean(text) }
    private var submitted: Bool { board?.submitted == true }
    private var myCaption: CaptionEntry? { board?.captions?.first(where: \.mine) }
    /// The board is unreachable or not set up: fall back to chat-only play.
    private var offline: Bool { !loading && (board == nil || board?.configured == false) }

    var body: some View {
        VStack(spacing: 0) {
            GameHeader(game: .captionMeme, onHome: onHome) {
                PixelStat(label: "MEME", value: "#\(day)")
            }
            ScrollView {
                VStack(spacing: 16) {
                    if let friendCaption, !session.incomingIsMine {
                        Text("\(incoming?.senderName ?? "A friend") captioned it:")
                            .font(Pixel.mono(13, .bold))
                            .foregroundColor(Pixel.muted)
                        MemeFrame(image: picture, art: meme.art, caption: friendCaption)
                    }
                    if submitted, let mine = myCaption {
                        MemeFrame(image: picture, art: meme.art, caption: mine.text)
                        chatButton(mine.text)
                        captionList
                    } else {
                        MemeFrame(image: picture, art: meme.art, caption: draft.isEmpty ? nil : draft)
                        composer
                    }
                    if let problem {
                        Text(problem)
                            .font(Pixel.mono(12, .bold))
                            .foregroundColor(Color(hex: 0xF07A84))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(18)
            }
            .refreshable { await load() }
        }
        .task { await load() }
        .confirmationDialog("Report this caption?", isPresented: Binding(
            get: { reporting != nil }, set: { if !$0 { reporting = nil } }
        ), titleVisibility: .visible, presenting: reporting) { entry in
            Button("Report and hide", role: .destructive) { Task { await report(entry) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Captions from this person will be hidden for you, and we'll review it.")
        }
    }

    // MARK: Writing

    private var composer: some View {
        VStack(spacing: 12) {
            TextField("", text: $text, prompt: Text("Write a caption").foregroundColor(Pixel.muted.opacity(0.6)),
                      axis: .vertical)
                .font(Pixel.mono(17, .bold))
                .foregroundColor(Pixel.cream)
                .lineLimit(1...3)
                .focused($typing)
                .onChange(of: text) { new in
                    if new.count > Caption.maxLength { text = String(new.prefix(Caption.maxLength)) }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .pixelBox(Pixel.row, step: 2)
            HStack(alignment: .top) {
                Text(hint)
                    .font(Pixel.mono(11))
                    .foregroundColor(Pixel.muted)
                Spacer()
                Text("\(text.count)/\(Caption.maxLength)")
                    .font(Pixel.mono(11, .bold))
                    .foregroundColor(Pixel.muted)
            }
            NameField(prompt: "Name (optional)")
            if offline {
                chatButton(draft)
                    .disabled(draft.isEmpty)
                    .opacity(draft.isEmpty ? 0.5 : 1)
            } else {
                PixelActionButton(title: busy ? "SUBMITTING..." : "SUBMIT") { Task { await submit() } }
                    .disabled(draft.isEmpty || busy || loading)
                    .opacity(draft.isEmpty || busy || loading ? 0.5 : 1)
            }
        }
    }

    private var hint: String {
        if loading { return "Loading today's captions..." }
        if offline { return "The caption board is offline. You can still send yours to the chat." }
        let n = board?.count ?? 0
        return n == 0 ? "Be the first to caption today's meme." : "\(n) \(n == 1 ? "caption" : "captions") so far. Submit yours to see them."
    }

    private func chatButton(_ caption: String) -> some View {
        SendButton(title: "SEND TO CHAT", payload: ScorePayload(game: .captionMeme, day: day, captionText: caption),
                   session: session, status: $status,
                   onSend: { DailyStore.record(ScorePayload(game: .captionMeme, day: day, captionText: caption)) })
    }

    // MARK: Board

    private var captionList: some View {
        let all = (board?.captions ?? []).filter { $0.mine || !muted.contains($0.author) }
        let votedFor = board?.votedFor
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                PixelText("TODAY'S CAPTIONS", scale: 2, color: Pixel.gold)
                Spacer()
                PixelText("\(all.count)", scale: 2, color: Pixel.muted, shadow: nil)
            }
            Text(votedFor == nil ? "Vote for the best one. One vote, and not your own." : "Thanks for voting. Pull down to refresh.")
                .font(Pixel.mono(11))
                .foregroundColor(Pixel.muted)
            if all.count == 1 {
                Text("Nobody else has captioned it yet. Check back later.")
                    .font(Pixel.mono(12))
                    .foregroundColor(Pixel.muted)
            }
            ForEach(all) { entry in
                row(entry, votedFor: votedFor)
            }
        }
    }

    private func row(_ entry: CaptionEntry, votedFor: String?) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(Pixel.mono(15, .bold))
                    .foregroundColor(Pixel.cream)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.mine ? "You\(entry.name.map { " · \($0)" } ?? "")" : (entry.name ?? "Anonymous"))
                    .font(Pixel.mono(11))
                    .foregroundColor(entry.mine ? Pixel.gold : Pixel.muted)
            }
            Spacer(minLength: 4)
            VStack(spacing: 6) {
                PixelText("\(entry.votes)", scale: 2, color: Pixel.cream)
                if entry.mine {
                    PixelText("YOURS", scale: 1.2, color: Pixel.muted, shadow: nil)
                } else if votedFor == entry.id {
                    PixelText("✓ VOTED", scale: 1.2, color: Pixel.green, shadow: nil)
                } else if votedFor == nil {
                    Button { Task { await vote(entry) } } label: {
                        PixelText("VOTE", scale: 1.5).padding(.horizontal, 6).padding(.vertical, 4)
                    }
                    .buttonStyle(PixelButtonStyle(step: 2))
                    .disabled(busy)
                }
            }
            if !entry.mine {
                Button { reporting = entry } label: {
                    Text("⚑").font(.system(size: 16)).foregroundColor(Pixel.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Report caption")
            }
        }
        .padding(12)
        .pixelBox(votedFor == entry.id ? Pixel.featured : Pixel.row, step: 2)
    }

    // MARK: Actions

    private func load() async {
        do {
            board = try await CaptionsAPI.board(day: day)
            problem = nil
        } catch {
            if board == nil { problem = nil } else { problem = error.localizedDescription }
        }
        loading = false
        if picture == nil, let m = board?.meme {
            picture = await MemeImages.load(day: day, url: m.url)
        }
    }

    private func submit() async {
        guard !draft.isEmpty, !busy else { return }
        busy = true
        typing = false
        defer { busy = false }
        do {
            board = try await CaptionsAPI.submit(day: day, text: draft, name: DailyStore.playerName)
            problem = nil
            DailyStore.record(ScorePayload(game: .captionMeme, day: day, captionText: draft))
        } catch {
            problem = error.localizedDescription
            // Already submitted on this device: show the board anyway.
            if let fresh = try? await CaptionsAPI.board(day: day), fresh.submitted == true { board = fresh }
        }
    }

    private func vote(_ entry: CaptionEntry) async {
        busy = true
        defer { busy = false }
        do {
            board = try await CaptionsAPI.vote(day: day, id: entry.id)
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }

    private func report(_ entry: CaptionEntry) async {
        muted.insert(entry.author)
        DailyStore.mutedAuthors = muted
        if let fresh = try? await CaptionsAPI.report(day: day, id: entry.id) { board = fresh }
    }
}

/// Today's meme in a gold pixel frame, with the caption in classic meme
/// lettering (heavy white capitals, black outline) along the bottom. Shows
/// the real template once it has loaded; until then (or offline) a pixel-art
/// stand-in.
struct MemeFrame: View {
    let image: UIImage?
    let art: PixelArt
    let caption: String?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size, contentMode: .fit)
                    .overlay(alignment: .bottom) { captionText }
            } else {
                GeometryReader { geo in
                    let scale = (geo.size.width / CGFloat(art.width)).rounded(.down)
                    ZStack(alignment: .bottom) {
                        PixelSprite(art: art, scale: scale)
                        captionText
                    }
                    .frame(width: geo.size.width, height: geo.size.width)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(8)
        .pixelBox(Pixel.featured, step: 4)
    }

    @ViewBuilder private var captionText: some View {
        if let caption {
            MemeText(caption.uppercased())
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
    }
}

/// White heavy text with a hard black outline, made from offset copies.
struct MemeText: View {
    let text: String
    init(_ text: String) { self.text = text }

    private static let outline: [CGSize] = [
        CGSize(width: -2, height: -2), CGSize(width: 2, height: -2), CGSize(width: -2, height: 2),
        CGSize(width: 2, height: 2), CGSize(width: 0, height: -2), CGSize(width: 0, height: 2),
        CGSize(width: -2, height: 0), CGSize(width: 2, height: 0),
    ]

    var body: some View {
        let base = Text(text).font(.system(size: 22, weight: .black, design: .default))
        ZStack {
            ForEach(0..<Self.outline.count, id: \.self) { i in
                base.foregroundColor(.black).offset(Self.outline[i])
            }
            base.foregroundColor(.white)
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .fixedSize(horizontal: false, vertical: true)
    }
}
