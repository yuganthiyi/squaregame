import SwiftUI

struct Tile: Identifiable {
    let id: Int
    let color: Color
    var shape: ShapeType
    var isMatched = false
    var isRevealed = false
}

enum ShapeType: CaseIterable {
    case roundedRectangle, circle, capsule, star, triangle
}

// Helper for custom shapes: Star & Triangle

struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let starPoints = 5
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let adjustment = -CGFloat.pi / 2

        var path = Path()

        for i in 0..<starPoints * 2 {
            let angle = (Double(i) * Double.pi / Double(starPoints)) + Double(adjustment)
            let pointRadius = i.isMultiple(of: 2) ? radius : radius * 0.4
            let x = center.x + CGFloat(cos(angle)) * pointRadius
            let y = center.y + CGFloat(sin(angle)) * pointRadius

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let top = CGPoint(x: rect.midX, y: rect.minY)
        let left = CGPoint(x: rect.minX, y: rect.maxY)
        let right = CGPoint(x: rect.maxX, y: rect.maxY)

        path.move(to: top)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()

        return path
    }
}

struct AnyShape: Shape {
    private let path: (CGRect) -> Path

    init<S: Shape>(_ wrapped: S) {
        path = { rect in
            wrapped.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}

struct GradientButtonLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct ContentView: View {
    @State private var tiles: [Tile] = []
    @State private var firstSelectionIndex: Int? = nil
    @State private var score: Int = 0
    @State private var timeRemaining: Int = 30
    @State private var lockInteraction: Bool = false
    @State private var showFinalScore: Bool = false
    @State private var currentRound: Int = 1
    @State private var gameStarted: Bool = false
    @State private var gameOver: Bool = false

    @State private var accumulatedTime = 0  // leftover time from previous round

    let totalRounds = 5
    let tileCounts = [8, 12, 16, 20, 24]  // total tiles per round (must be even)
    let allColors: [Color] = [.red, .green, .blue, .orange, .yellow, .purple, .pink, .cyan, .mint, .indigo, .teal, .brown]
    let allShapes: [ShapeType] = ShapeType.allCases

    @State private var gameTimer: Timer?

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.6)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if !gameStarted {
                    introScreen
                } else {
                    gameHeader
                    if showFinalScore || gameOver {
                        endGameView
                    } else {
                        gameGrid
                        quitButton
                    }
                }
            }
            .padding()
            .transition(.opacity)
        }
    }

    // MARK: - Intro Screen
    var introScreen: some View {
        VStack(spacing: 30) {
            Text("🎨 Colour Match Game")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Match all pairs before time runs out!")
                .foregroundColor(.white.opacity(0.85))
                .font(.title3)

            Button(action: {
                withAnimation {
                    gameStarted = true
                    accumulatedTime = 0
                    resetGameVars()
                    startNewRound()
                }
            }) {
                GradientButtonLabel(text: "Start Game")
            }
        }
        .padding()
    }

    // MARK: - Game Header
    var gameHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Score: \(score)")
                    .font(.title3)
                    .foregroundColor(.white)
                Spacer()
                Text("Time: \(timeRemaining)s")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            ProgressView(value: Double(timeRemaining),
                         total: Double(30 + (currentRound - 1) * 10 + accumulatedTime))
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
        }
        .padding(.horizontal)
    }

    // MARK: - End Game View
    var endGameView: some View {
        VStack(spacing: 24) {
            Text(gameOver ? "⏱ Game Over" : "🎉 You Won!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Final Score: \(score)")
                .font(.title2)
                .foregroundColor(.white)

            Button(action: {
                withAnimation {
                    resetGameVars()
                    startNewRound()
                    showFinalScore = false
                    gameOver = false
                }
            }) {
                GradientButtonLabel(text: "Play Again")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
        .padding(.top, 40)
    }

    // MARK: - Quit Button
    var quitButton: some View {
        Button(action: {
            withAnimation {
                stopTimer()
                resetGameVars()
                gameStarted = false
                showFinalScore = false
                gameOver = false
            }
        }) {
            Text("Quit")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.7))
                .cornerRadius(12)
        }
        .padding(.top)
    }

    // MARK: - Game Grid
    var gameGrid: some View {
        let columns = getColumnCount()
        return VStack {
            Text("Round \(currentRound) of \(totalRounds)")
                .font(.headline)
                .foregroundColor(.white.opacity(0.85))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                ForEach(tiles) { tile in
                    ZStack {
                        shapeView(for: tile)
                            .fill(tile.isMatched || tile.isRevealed ? tile.color : Color.white.opacity(0.15))
                            .frame(height: 80)
                            .overlay(
                                shapeView(for: tile)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                            .overlay(
                                tile.isMatched
                                    ? Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24, weight: .bold))
                                    : nil
                            )
                            .rotation3DEffect(
                                .degrees(tile.isRevealed || tile.isMatched ? 0 : 180),
                                axis: (x: 0, y: 1, z: 0)
                            )
                            .animation(.easeInOut(duration: 0.3), value: tile.isRevealed)
                    }
                    .onTapGesture {
                        handleTap(on: tile.id)
                    }
                    .disabled(tile.isMatched || tile.isRevealed || lockInteraction)
                }
            }
            .padding(.top)
        }
    }

    func shapeView(for tile: Tile) -> some Shape {
        switch tile.shape {
        case .roundedRectangle:
            return AnyShape(RoundedRectangle(cornerRadius: 12))
        case .circle:
            return AnyShape(Circle())
        case .capsule:
            return AnyShape(Capsule())
        case .star:
            return AnyShape(StarShape())
        case .triangle:
            return AnyShape(TriangleShape())
        }
    }

    func getTileCount() -> Int {
        tileCounts[currentRound - 1]
    }

    func getColumnCount() -> Int {
        return 4
    }

    func resetGameVars() {
        stopTimer()
        score = 0
        currentRound = 1
        firstSelectionIndex = nil
        lockInteraction = false
        accumulatedTime = 0
        tiles = []
    }

    func startNewRound() {
        stopTimer()
        timeRemaining = 30 + (currentRound - 1) * 10 + accumulatedTime
        accumulatedTime = 0
        firstSelectionIndex = nil
        lockInteraction = false

        let tileCount = getTileCount()
        let pairCount = tileCount / 2

        // Randomly pick colors and shapes for pairs
        let selectedColors = Array(allColors.shuffled().prefix(pairCount))
        let selectedShapes = Array(allShapes.shuffled().prefix(pairCount))

        var tilePairs: [Tile] = []
        for i in 0..<pairCount {
            let color = selectedColors[i]
            let shape = selectedShapes[i % selectedShapes.count]
            tilePairs.append(Tile(id: i * 2, color: color, shape: shape))
            tilePairs.append(Tile(id: i * 2 + 1, color: color, shape: shape))
        }

        tiles = tilePairs.shuffled()

        startTimer()
    }

    func startTimer() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                gameOver = true
                stopTimer()
            }
        }
    }

    func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func handleTap(on id: Int) {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        guard !tiles[index].isRevealed && !tiles[index].isMatched && !lockInteraction else { return }

        tiles[index].isRevealed = true

        if let firstIndex = firstSelectionIndex {
            // Second selection
            lockInteraction = true
            if tiles[firstIndex].color == tiles[index].color &&
                tiles[firstIndex].shape == tiles[index].shape {
                // It's a match (same color and shape)
                tiles[firstIndex].isMatched = true
                tiles[index].isMatched = true
                score += 10
                lockInteraction = false
                firstSelectionIndex = nil

                // Check if round complete
                if tiles.allSatisfy({ $0.isMatched }) {
                    stopTimer()
                    accumulatedTime = timeRemaining
                    if currentRound == totalRounds {
                        showFinalScore = true
                    } else {
                        currentRound += 1
                        startNewRound()
                    }
                }
            } else {
                // Not a match, flip back after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    tiles[firstIndex].isRevealed = false
                    tiles[index].isRevealed = false
                    lockInteraction = false
                    firstSelectionIndex = nil
                }
            }
        } else {
            // First selection
            firstSelectionIndex = index
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
