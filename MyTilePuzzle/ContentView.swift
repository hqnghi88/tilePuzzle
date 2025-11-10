import SwiftUI

// MARK: - Model

enum Direction: CaseIterable {
    case up, down, left, right
}

enum TileType: CaseIterable {
    case corner, straight, tJunction, cross, empty, deadEnd
}

struct Tile: Identifiable {
    let id = UUID()
    var type: TileType
    var rotation: Double = 0.0 // Angle in degrees

    var connections: Set<Direction> {
        if type == .empty {
            return []
        }
        
        let effectiveRotation = (Int(rotation / 90) % 4 + 4) % 4
        
        let rotatedConnections = baseConnections.map { (direction: Direction) -> Direction in
            var rotatedDirection = direction
            for _ in 0..<effectiveRotation {
                rotatedDirection = rotatedDirection.rotatedRight()
            }
            return rotatedDirection
        }
        return Set(rotatedConnections)
    }

    private var baseConnections: Set<Direction> {
        switch type {
        case .corner:
            return [.up, .left]
        case .straight:
            return [.up, .down]
        case .tJunction:
            return [.up, .left, .right]
        case .cross:
            return [.up, .down, .left, .right]
        case .empty:
            return []
        case .deadEnd:
            return [.up]
        }
    }
}

extension Direction {
    func rotatedRight() -> Direction {
        switch self {
        case .up: return .right
        case .right: return .down
        case .down: return .left
        case .left: return .up
        }
    }
    
    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}


// MARK: - ViewModel

class GameViewModel: ObservableObject {
    @Published var grid: [[Tile]]
    @Published var isGameWon = false
    @Published var level = 1
    
    var gridSize: Int {
        level + 2
    }
    
    var source: [Int] {
        [0, 0]
    }
    
    var destination: [Int] {
        [gridSize - 1, gridSize - 1]
    }

    init() {
        self.grid = []
        generateRandomGrid()
    }

    func generateRandomGrid() {
        isGameWon = false
        
        // Start with a fresh grid
        grid = Array(repeating: Array(repeating: Tile(type: .empty), count: gridSize), count: gridSize)
        
        let path = generateSolutionPath()

        // Create the path tiles
        for (i, pos) in path.enumerated() {
            let r = pos[0]
            let c = pos[1]
            
            let prevPos = i > 0 ? path[i-1] : nil
            let nextPos = i < path.count - 1 ? path[i+1] : nil
            
            var connections = Set<Direction>()
            if let prev = prevPos {
                if prev[0] < r { connections.insert(.up) }
                else if prev[0] > r { connections.insert(.down) }
                else if prev[1] < c { connections.insert(.left) }
                else if prev[1] > c { connections.insert(.right) }
            }
            if let next = nextPos {
                if next[0] < r { connections.insert(.up) }
                else if next[0] > r { connections.insert(.down) }
                else if next[1] < c { connections.insert(.left) }
                else if next[1] > c { connections.insert(.right) }
            }
            
            let (type, rotation) = tileTypeAndRotation(for: connections)
            grid[r][c] = Tile(type: type, rotation: rotation)
        }
        
        // Randomly rotate all tiles on the path
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if grid[r][c].type != .empty {
                    grid[r][c].rotation = [0.0, 90.0, 180.0, 270.0].randomElement()!
                }
            }
        }
        
        checkWinCondition()
    }
    
    func nextLevel() {
        level += 1
        generateRandomGrid()
    }
    
    private func generateSolutionPath() -> [[Int]] {
        var path: [[Int]] = []
        var visited = Set<[Int]>()
        
        func findPath(from: [Int]) -> Bool {
            visited.insert(from)
            path.append(from)
            
            if from == destination {
                return true
            }
            
            let neighbors = getNeighbors(of: from).shuffled()
            
            for neighbor in neighbors {
                if !visited.contains(neighbor) {
                    if findPath(from: neighbor) {
                        return true
                    }
                }
            }
            
            path.removeLast()
            return false
        }
        
        _ = findPath(from: source)
        return path
    }
    
    private func getNeighbors(of pos: [Int]) -> [[Int]] {
        let r = pos[0]
        let c = pos[1]
        var neighbors: [[Int]] = []
        if r > 0 { neighbors.append([r - 1, c]) }
        if r < gridSize - 1 { neighbors.append([r + 1, c]) }
        if c > 0 { neighbors.append([r, c - 1]) }
        if c < gridSize - 1 { neighbors.append([r, c + 1]) }
        return neighbors
    }
    
    private func tileTypeAndRotation(for connections: Set<Direction>) -> (TileType, Double) {
        if connections.count == 1 {
            let dir = connections.first!
            if dir == .up { return (.deadEnd, 0) }
            if dir == .right { return (.deadEnd, 90) }
            if dir == .down { return (.deadEnd, 180) }
            if dir == .left { return (.deadEnd, 270) }
        }
        
        if connections.count == 2 {
            if connections == Set([.up, .down]) { return (.straight, 0) }
            if connections == Set([.left, .right]) { return (.straight, 90) }
            
            if connections == Set([.up, .left]) { return (.corner, 0) }
            if connections == Set([.up, .right]) { return (.corner, 90) }
            if connections == Set([.down, .right]) { return (.corner, 180) }
            if connections == Set([.down, .left]) { return (.corner, 270) }
        }
        
        return (.empty, 0)
    }


    func rotateTile(at row: Int, col: Int) {
        if grid[row][col].type != .empty {
            grid[row][col].rotation += 90
            checkWinCondition()
        }
    }

    private func checkWinCondition() {
        var component = Set<[Int]>()
        var queue = [source]
        component.insert(source)

        var head = 0
        while head < queue.count {
            let currentPos = queue[head]; head += 1
            let r = currentPos[0], c = currentPos[1]
            let tile = grid[r][c]

            for direction in tile.connections {
                var nr = r, nc = c
                switch direction {
                case .up: nr -= 1; case .down: nr += 1; case .left: nc -= 1; case .right: nc += 1
                }

                if nr >= 0, nr < gridSize, nc >= 0, nc < gridSize, !component.contains([nr, nc]) {
                    if grid[nr][nc].connections.contains(direction.opposite) {
                        component.insert([nr, nc]); queue.append([nr, nc])
                    }
                }
            }
        }

        guard component.contains(destination) else { isGameWon = false; return }

        for pos in component {
            let r = pos[0], c = pos[1]
            let tile = grid[r][c]
            var internalConnections = 0

            for direction in tile.connections {
                var nr = r, nc = c
                switch direction {
                case .up: nr -= 1; case .down: nr += 1; case .left: nc -= 1; case .right: nc += 1
                }
                
                if component.contains([nr, nc]) && grid[nr][nc].connections.contains(direction.opposite) {
                    internalConnections += 1
                }
            }

            if pos == source || pos == destination {
                if internalConnections != 1 { isGameWon = false; return }
            } else {
                if internalConnections != 2 { isGameWon = false; return }
            }
        }
        
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if !component.contains([r,c]) && grid[r][c].type != .empty {
                    isGameWon = false; return
                }
            }
        }

        isGameWon = true
    }
}

// MARK: - Views

struct TileShape: Shape {
    let type: TileType

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfSize = min(rect.width, rect.height) / 2

        switch type {
        case .corner:
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - halfSize, y: center.y - 5, width: halfSize, height: 10)))
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - 5, y: center.y - halfSize, width: 10, height: halfSize)))
        case .straight:
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - 5, y: center.y - halfSize, width: 10, height: halfSize * 2)))
        case .tJunction:
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - halfSize, y: center.y - 5, width: halfSize * 2, height: 10)))
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - 5, y: center.y - halfSize, width: 10, height: halfSize)))
        case .cross:
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - halfSize, y: center.y - 5, width: halfSize * 2, height: 10)))
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - 5, y: center.y - halfSize, width: 10, height: halfSize * 2)))
        case .deadEnd:
            path.addPath(Capsule(style: .continuous).path(in: CGRect(x: center.x - 5, y: center.y - halfSize, width: 10, height: halfSize)))
        case .empty:
            break
        }
        
        return path
    }
}


struct TileView: View {
    let tile: Tile
    let isSource: Bool
    let isDestination: Bool

    var body: some View {
        let backgroundColor = isSource ? Color.blue.opacity(0.5) : (isDestination ? Color.green.opacity(0.5) : Color.clear)
        let pipeColor = LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
        
        ZStack {
            backgroundColor
            
            TileShape(type: tile.type)
                .fill(pipeColor)
                .rotationEffect(.degrees(tile.rotation))
                .animation(.easeInOut, value: tile.rotation)
        }
        .frame(width: 50, height: 50)
        .background(.white.opacity(0.1))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack {
                Text("Level \(viewModel.level)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                    .shadow(radius: 10)

                Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                    ForEach(0..<viewModel.gridSize, id: \.self) { row in
                        GridRow {
                            ForEach(0..<viewModel.gridSize, id: \.self) { col in
                                let isSource = row == viewModel.source[0] && col == viewModel.source[1]
                                let isDestination = row == viewModel.destination[0] && col == viewModel.destination[1]
                                TileView(tile: viewModel.grid[row][col], isSource: isSource, isDestination: isDestination)
                                    .onTapGesture {
                                        withAnimation {
                                            viewModel.rotateTile(at: row, col: col)
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)


                if viewModel.isGameWon {
                    Button("Next Level") {
                        withAnimation {
                            viewModel.nextLevel()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding()
                    .shadow(radius: 5)
                }

                Button("Reset") {
                    withAnimation {
                        viewModel.generateRandomGrid()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding()
                .shadow(radius: 5)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}