//
//  ContentView.swift
//  squaregame
//
//  Created by Yuganthi 035 on 2025-05-04.
//
import SwiftUI

struct Tile: Identifiable {
    let id: Int
    var color: Color
    var isMatched: Bool = false
    var isRevealed: Bool = false
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

    let totalRounds = 3
    let tileCounts = [8, 12, 16]
    let allColors: [Color] = [.red, .green, .blue, .orange, .yellow, .purple, .pink, .cyan, .mint, .indigo, .teal, .brown]

    @State private var gameTimer: Timer?

    var body: some View {
        ZStack {
            // Background
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

            ProgressView(value: Double(timeRemaining), total: Double(30 + (currentRound - 1) * 10))
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

            Button(action: resetGame) {
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tile.isMatched || tile.isRevealed ? tile.color : Color.white.opacity(0.15))
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                            .overlay(
                                tile.isMatched
                                    ? Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 24, weight: .bold))
                                        .transition(.scale)
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

    // MARK: - Game Logic

    func getTileCount() -> Int {
        tileCounts[currentRound - 1]
    }

    func getColumnCount() -> Int {
        return 4
    }

    func resetGame() {
        score = 0
        currentRound = 1
        showFinalScore = false
        gameOver = false
        firstSelectionIndex = nil
        lockInteraction = false
        startNewRound()
    }

    func startNewRound() {
        stopTimer()
        timeRemaining = 30 + (currentRound - 1) * 10
        firstSelectionIndex = nil
        lockInteraction = false

        let tileCount = getTileCount()
        let pairCount = tileCount / 2

        var selectedColors = Array(allColors.shuffled().prefix(pairCount))
        var tileColors = (selectedColors + selectedColors).shuffled()

        if tileColors.count < tileCount {
            tileColors.append(allColors.randomElement()!)
        }

        tiles = (0..<tileColors.count).map { i in
            Tile(id: i, color: tileColors[i])
        }

        startTimer()
    }

    func startTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
                if tiles.allSatisfy({ $0.isMatched }) {
                    advanceToNextRound()
                } else {
                    gameOver = true
                }
            }
        }
    }

    func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func handleTap(on id: Int) {
        guard let index = tiles.firstIndex(where: { $0.id == id }),
              !tiles[index].isMatched,
              !tiles[index].isRevealed else { return }

        tiles[index].isRevealed = true

        if let firstIndex = firstSelectionIndex {
            if tiles[firstIndex].color == tiles[index].color {
                lockInteraction = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    tiles[firstIndex].isMatched = true
                    tiles[index].isMatched = true
                    tiles[firstIndex].isRevealed = false
                    tiles[index].isRevealed = false
                    score += 10
                    lockInteraction = false
                    firstSelectionIndex = nil
                    checkRoundComplete()
                }
            } else {
                lockInteraction = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    tiles[firstIndex].isRevealed = false
                    tiles[index].isRevealed = false
                    firstSelectionIndex = nil
                    lockInteraction = false
                }
            }
        } else {
            firstSelectionIndex = index
        }
    }

    func checkRoundComplete() {
        if tiles.allSatisfy({ $0.isMatched }) {
            stopTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                advanceToNextRound()
            }
        }
    }

    func advanceToNextRound() {
        if currentRound < totalRounds {
            currentRound += 1
            startNewRound()
        } else {
            showFinalScore = true
        }
    }
}

// MARK: - Gradient Button Label

struct GradientButtonLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.title3).bold()
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 2, y: 4)
    }
}

#Preview {
    ContentView()
}

