import Combine
import SwiftUI

struct ContentView: View {
    @State private var level = EditableLevel.starter()
    @State private var selectedTool: CreatorTool = .block
    @State private var camera = LevelGridPoint(x: 0, y: 3)
    @State private var isPlaying = false
    @State private var playState = LevelPlayState(level: EditableLevel.starter())
    @State private var isPressingLeft = false
    @State private var isPressingRight = false
    @State private var queuedJump = false
    @State private var lastTickDate: Date?

    private let gameTimer = Timer.publish(every: 1.0 / 45.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 10) {
                header

                StatusStrip(
                    isPlaying: isPlaying,
                    selectedTool: selectedTool,
                    level: level,
                    playState: playState
                )

                LevelCanvasView(
                    level: level,
                    selectedTool: selectedTool,
                    camera: camera,
                    isPlaying: isPlaying,
                    playState: playState,
                    applyAction: applyTool,
                    movingDragAction: updateMovingPlatform,
                    cameraDragAction: moveCameraByDrag
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 4)

                if isPlaying {
                    PlayControls(
                        isPressingLeft: $isPressingLeft,
                        isPressingRight: $isPressingRight,
                        jumpAction: { queuedJump = true },
                        attackAction: performAttack,
                        canAttack: playState.attackCooldown <= 0
                    )
                } else {
                    EditorControls(
                        selectedTool: $selectedTool,
                        camera: camera,
                        moveCameraAction: moveCamera,
                        resetAction: resetLevel
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .onAppear {
            camera = clampedCamera(x: 0, y: 3)
        }
        .onReceive(gameTimer) { date in
            guard isPlaying else {
                lastTickDate = date
                return
            }

            let delta = min(CGFloat(date.timeIntervalSince(lastTickDate ?? date)), 1.0 / 20.0)
            lastTickDate = date
            stepPlay(deltaTime: delta)
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isPlaying)
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Level Creator")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(isPlaying ? playState.statusText : selectedTool.hint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            Button {
                togglePlay()
            } label: {
                Label(isPlaying ? "Creator" : "Play", systemImage: isPlaying ? "hammer.fill" : "play.fill")
                    .font(.headline.weight(.black))
                    .frame(minWidth: 96, minHeight: 40)
            }
            .buttonStyle(PrimaryButtonStyle(isActive: isPlaying))
        }
    }

    private func applyTool(at point: LevelGridPoint) {
        guard level.contains(point) else { return }

        switch selectedTool {
        case .block:
            level.tiles[point] = .block
            removeActors(at: point)
        case .kill:
            level.tiles[point] = .kill
            removeActors(at: point)
        case .water:
            level.tiles[point] = .water
            removeActors(at: point)
        case .space:
            level.tiles[point] = .space
            removeActors(at: point)
        case .moving:
            let end = level.clamped(LevelGridPoint(x: point.x + 4, y: point.y))
            updateMovingPlatform(start: point, end: end)
        case .enemy:
            level.tiles[point] = nil
            level.movingPlatforms.removeAll { $0.touches(point) }
            if level.enemies.contains(point) {
                level.enemies.remove(point)
            } else if point != level.start && point != level.end {
                level.enemies.insert(point)
            }
        case .start:
            level.tiles[point] = nil
            removeActors(at: point)
            level.start = point
        case .end:
            level.tiles[point] = nil
            removeActors(at: point)
            level.end = point
        case .delete:
            level.tiles[point] = nil
            level.enemies.remove(point)
            level.movingPlatforms.removeAll { $0.touches(point) }
        case .move:
            break
        }
    }

    private func removeActors(at point: LevelGridPoint) {
        level.enemies.remove(point)
        level.movingPlatforms.removeAll { $0.touches(point) }
    }

    private func updateMovingPlatform(start: LevelGridPoint, end: LevelGridPoint) {
        let safeStart = level.clamped(start)
        var safeEnd = level.clamped(end)
        if safeEnd == safeStart {
            safeEnd = level.clamped(LevelGridPoint(x: safeStart.x + 1, y: safeStart.y))
        }

        level.tiles[safeStart] = nil
        level.enemies.remove(safeStart)
        level.enemies.remove(safeEnd)

        if let index = level.movingPlatforms.firstIndex(where: { $0.start == safeStart }) {
            level.movingPlatforms[index].end = safeEnd
        } else {
            level.movingPlatforms.append(LevelMovingPlatform(start: safeStart, end: safeEnd))
        }
    }

    private func togglePlay() {
        if isPlaying {
            isPlaying = false
            isPressingLeft = false
            isPressingRight = false
            queuedJump = false
            lastTickDate = nil
            return
        }

        playState = LevelPlayState(level: level)
        isPlaying = true
        lastTickDate = nil
        centerCamera(on: CGPoint(x: playState.playerX, y: playState.playerY))
    }

    private func resetLevel() {
        level = EditableLevel.starter()
        selectedTool = .block
        camera = clampedCamera(x: 0, y: 3)
        playState = LevelPlayState(level: level)
        isPlaying = false
    }

    private func moveCamera(dx: Int, dy: Int) {
        camera = clampedCamera(x: camera.x + dx, y: camera.y + dy)
    }

    private func moveCameraByDrag(_ translation: CGSize, cellSize: CGFloat) {
        guard selectedTool == .move else { return }

        let dragX = Int((translation.width / max(cellSize, 1)).rounded())
        let dragY = Int((translation.height / max(cellSize, 1)).rounded())
        guard dragX != 0 || dragY != 0 else { return }
        moveCamera(dx: -dragX, dy: -dragY)
    }

    private func centerCamera(on point: CGPoint) {
        let targetX = Int(point.x.rounded(.down)) - GameConstants.viewportColumns / 2
        let targetY = Int(point.y.rounded(.down)) - GameConstants.viewportRows / 2
        camera = clampedCamera(x: targetX, y: targetY)
    }

    private func clampedCamera(x: Int, y: Int) -> LevelGridPoint {
        let maxX = max(0, level.width - GameConstants.viewportColumns)
        let maxY = max(0, level.height - GameConstants.viewportRows)
        return LevelGridPoint(
            x: min(max(x, 0), maxX),
            y: min(max(y, 0), maxY)
        )
    }

    private func stepPlay(deltaTime: CGFloat) {
        guard playState.isComplete == false else { return }

        var state = playState
        state.attackCooldown = max(0, state.attackCooldown - deltaTime)
        state.attackFlash = max(0, state.attackFlash - deltaTime)
        state.invulnerability = max(0, state.invulnerability - deltaTime)

        for index in state.platforms.indices {
            state.platforms[index].advance(deltaTime: deltaTime)
        }
        carryPlayerIfStanding(on: &state)

        let movement = (isPressingRight ? CGFloat(1) : 0) - (isPressingLeft ? CGFloat(1) : 0)
        if movement != 0 {
            state.facing = movement
        }

        var speed = GameConstants.playerSpeed
        let foot = LevelGridPoint(x: Int(state.playerX.rounded(.down)), y: Int((state.playerY + 0.45).rounded(.down)))
        let currentTile = level.tiles[foot]
        if currentTile == .water || currentTile == .space {
            speed = GameConstants.boostSpeed
            state.velocityX += state.facing * 3.6 * deltaTime
            if currentTile == .water {
                state.velocityY -= 2.2 * deltaTime
            }
            state.statusText = currentTile == .water ? "Water current boost" : "Space block boost"
        }

        state.velocityX = movement * speed + state.velocityX * 0.68

        if queuedJump && state.isGrounded {
            state.velocityY = -GameConstants.jumpVelocity
            state.isGrounded = false
            state.statusText = "Jump"
        }
        queuedJump = false

        state.velocityY += GameConstants.gravity * deltaTime
        movePlayer(&state, deltaTime: deltaTime)
        moveEnemies(&state, deltaTime: deltaTime)
        handleHazards(&state)
        handleEnemyContact(&state)
        handleGoal(&state)

        if state.playerY > CGFloat(level.height + 3) {
            state = respawnState(message: "Respawned")
        }

        playState = state
        centerCamera(on: CGPoint(x: state.playerX, y: state.playerY))
    }

    private func carryPlayerIfStanding(on state: inout LevelPlayState) {
        guard state.velocityY >= -0.1 else { return }

        let playerBottom = state.playerY + GameConstants.playerHeight / 2
        for platform in state.platforms {
            let top = platform.previousY - GameConstants.platformHeight / 2
            let withinX = abs(state.playerX - platform.previousX) < GameConstants.platformWidth * 0.62
            let standingOnTop = abs(playerBottom - top) < 0.18
            if withinX && standingOnTop {
                state.playerX += platform.deltaX
                state.playerY += platform.deltaY
                return
            }
        }
    }

    private func movePlayer(_ state: inout LevelPlayState, deltaTime: CGFloat) {
        let proposedX = state.playerX + state.velocityX * deltaTime
        if collides(centerX: proposedX, centerY: state.playerY, state: state) {
            state.velocityX = 0
        } else {
            state.playerX = proposedX
        }

        let proposedY = state.playerY + state.velocityY * deltaTime
        if collides(centerX: state.playerX, centerY: proposedY, state: state) {
            if state.velocityY > 0 {
                state.isGrounded = true
            }
            state.velocityY = 0
        } else {
            state.playerY = proposedY
            state.isGrounded = collides(centerX: state.playerX, centerY: state.playerY + 0.08, state: state)
        }
    }

    private func moveEnemies(_ state: inout LevelPlayState, deltaTime: CGFloat) {
        for index in state.enemies.indices {
            var enemy = state.enemies[index]
            let nextX = enemy.x + enemy.direction * GameConstants.enemySpeed * deltaTime
            let noseX = nextX + enemy.direction * 0.48
            let wallAhead = level.isSolid(at: LevelGridPoint(x: Int(noseX.rounded(.down)), y: Int(enemy.y.rounded(.down))))
            let floorAhead = level.isSolid(at: LevelGridPoint(x: Int(noseX.rounded(.down)), y: Int((enemy.y + 0.72).rounded(.down))))

            if wallAhead || floorAhead == false {
                enemy.direction *= -1
            } else {
                enemy.x = nextX
            }

            state.enemies[index] = enemy
        }
    }

    private func performAttack() {
        guard isPlaying, playState.attackCooldown <= 0 else { return }

        var state = playState
        state.attackCooldown = 0.34
        state.attackFlash = 0.18
        let reachX = state.playerX + state.facing * 1.08
        let before = state.enemies.count
        state.enemies.removeAll { enemy in
            abs(enemy.x - reachX) < 1.15 && abs(enemy.y - state.playerY) < 1.05
        }
        state.statusText = state.enemies.count < before ? "Enemy hit" : "Attack"
        playState = state
    }

    private func handleHazards(_ state: inout LevelPlayState) {
        if touchesTile(kind: .kill, state: state) {
            state = respawnState(message: "Kill block")
        }
    }

    private func handleEnemyContact(_ state: inout LevelPlayState) {
        guard state.invulnerability <= 0 else { return }

        let touchedEnemy = state.enemies.contains { enemy in
            abs(enemy.x - state.playerX) < 0.72 && abs(enemy.y - state.playerY) < 0.76
        }

        guard touchedEnemy else { return }
        state.health -= 1
        state.invulnerability = 1.0
        state.velocityY = -5.2
        state.velocityX = -state.facing * 2.8
        state.statusText = "Enemy contact"

        if state.health <= 0 {
            state = respawnState(message: "Respawned")
        }
    }

    private func handleGoal(_ state: inout LevelPlayState) {
        let goalX = CGFloat(level.end.x) + 0.5
        let goalY = CGFloat(level.end.y) + 0.5
        if abs(state.playerX - goalX) < 0.78 && abs(state.playerY - goalY) < 0.92 {
            state.isComplete = true
            state.statusText = "Level complete"
        }
    }

    private func respawnState(message: String) -> LevelPlayState {
        var state = LevelPlayState(level: level)
        state.statusText = message
        return state
    }

    private func touchesTile(kind: LevelTileKind, state: LevelPlayState) -> Bool {
        let halfWidth = GameConstants.playerWidth / 2
        let halfHeight = GameConstants.playerHeight / 2
        let left = Int((state.playerX - halfWidth).rounded(.down))
        let right = Int((state.playerX + halfWidth).rounded(.down))
        let top = Int((state.playerY - halfHeight).rounded(.down))
        let bottom = Int((state.playerY + halfHeight).rounded(.down))

        for y in top...bottom {
            for x in left...right {
                if level.tiles[LevelGridPoint(x: x, y: y)] == kind {
                    return true
                }
            }
        }

        return false
    }

    private func collides(centerX: CGFloat, centerY: CGFloat, state: LevelPlayState) -> Bool {
        let halfWidth = GameConstants.playerWidth / 2
        let halfHeight = GameConstants.playerHeight / 2
        let playerRect = CGRect(
            x: centerX - halfWidth,
            y: centerY - halfHeight,
            width: GameConstants.playerWidth,
            height: GameConstants.playerHeight
        )

        let left = Int(playerRect.minX.rounded(.down))
        let right = Int(playerRect.maxX.rounded(.down))
        let top = Int(playerRect.minY.rounded(.down))
        let bottom = Int(playerRect.maxY.rounded(.down))

        for y in top...bottom {
            for x in left...right {
                if level.isSolid(at: LevelGridPoint(x: x, y: y)) {
                    return true
                }
            }
        }

        for platform in state.platforms {
            if playerRect.intersects(platform.collisionRect) {
                return true
            }
        }

        return false
    }
}

private struct StatusStrip: View {
    let isPlaying: Bool
    let selectedTool: CreatorTool
    let level: EditableLevel
    let playState: LevelPlayState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Badge(symbol: isPlaying ? "gamecontroller.fill" : selectedTool.symbolName, text: isPlaying ? "Playtest" : selectedTool.title, tint: isPlaying ? Color.sky : selectedTool.tint)
                Badge(symbol: "flag.fill", text: "Start \(level.start.x),\(level.start.y)", tint: Color.mintPop)
                Badge(symbol: "scope", text: "End \(level.end.x),\(level.end.y)", tint: Color.gold)
                Badge(symbol: "arrow.left.and.right", text: "\(level.movingPlatforms.count) moving", tint: Color.purplePop)

                if isPlaying {
                    Badge(symbol: "heart.fill", text: "\(playState.health)", tint: Color.redPop)
                    Badge(symbol: "bolt.fill", text: "\(playState.enemies.count) foes", tint: Color.violetSoft)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct Badge: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(tint)

            Text(text)
                .font(.caption.weight(.black))
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct LevelCanvasView: View {
    let level: EditableLevel
    let selectedTool: CreatorTool
    let camera: LevelGridPoint
    let isPlaying: Bool
    let playState: LevelPlayState
    let applyAction: (LevelGridPoint) -> Void
    let movingDragAction: (LevelGridPoint, LevelGridPoint) -> Void
    let cameraDragAction: (CGSize, CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = ViewportMetrics(availableSize: proxy.size)

            ZStack {
                board(metrics: metrics)
                    .frame(width: metrics.boardWidth, height: metrics.boardHeight)
                    .shadow(color: Color.black.opacity(0.42), radius: 20, y: 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func board(metrics: ViewportMetrics) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.055, green: 0.065, blue: 0.08), Color(red: 0.08, green: 0.1, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            ForEach(0..<GameConstants.viewportRows, id: \.self) { row in
                ForEach(0..<GameConstants.viewportColumns, id: \.self) { column in
                    let point = LevelGridPoint(x: camera.x + column, y: camera.y + row)
                    TileCell(
                        point: point,
                        tile: level.tiles[point],
                        isStart: point == level.start,
                        isEnd: point == level.end,
                        hasEnemy: level.enemies.contains(point),
                        isMoveTool: selectedTool == .move
                    )
                    .frame(width: metrics.cellSize, height: metrics.cellSize)
                    .position(
                        x: CGFloat(column) * metrics.cellSize + metrics.cellSize / 2,
                        y: CGFloat(row) * metrics.cellSize + metrics.cellSize / 2
                    )
                }
            }

            ForEach(level.movingPlatforms) { platform in
                if lineIsVisible(platform) {
                    movingPath(platform, metrics: metrics)
                }
            }

            if isPlaying {
                ForEach(playState.platforms) { platform in
                    if isVisible(x: platform.x, y: platform.y) {
                        MovingPlatformView()
                            .frame(width: metrics.cellSize * 0.96, height: metrics.cellSize * 0.42)
                            .position(
                                x: (platform.x - CGFloat(camera.x)) * metrics.cellSize,
                                y: (platform.y - CGFloat(camera.y)) * metrics.cellSize
                            )
                    }
                }

                ForEach(playState.enemies) { enemy in
                    if isVisible(x: enemy.x, y: enemy.y) {
                        EnemyView(direction: enemy.direction)
                            .frame(width: metrics.cellSize * 0.78, height: metrics.cellSize * 0.78)
                            .position(
                                x: (enemy.x - CGFloat(camera.x)) * metrics.cellSize,
                                y: (enemy.y - CGFloat(camera.y)) * metrics.cellSize
                            )
                    }
                }

                if isVisible(x: playState.playerX, y: playState.playerY) {
                    PlayerView(
                        facing: playState.facing,
                        isInvulnerable: playState.invulnerability > 0,
                        isAttacking: playState.attackFlash > 0
                    )
                    .frame(width: metrics.cellSize * 0.78, height: metrics.cellSize * 0.92)
                    .position(
                        x: (playState.playerX - CGFloat(camera.x)) * metrics.cellSize,
                        y: (playState.playerY - CGFloat(camera.y)) * metrics.cellSize
                    )
                }
            } else {
                ForEach(level.movingPlatforms) { platform in
                    if isVisible(point: platform.start) {
                        MovingPlatformView()
                            .frame(width: metrics.cellSize * 0.96, height: metrics.cellSize * 0.42)
                            .position(
                                x: pointCenter(platform.start, metrics: metrics).x,
                                y: pointCenter(platform.start, metrics: metrics).y
                            )
                    }

                    if isVisible(point: platform.end) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: max(16, metrics.cellSize * 0.58), weight: .black))
                            .foregroundStyle(Color.purplePop)
                            .rotationEffect(angle(for: platform))
                            .shadow(color: Color.purplePop.opacity(0.45), radius: 8)
                            .position(
                                x: pointCenter(platform.end, metrics: metrics).x,
                                y: pointCenter(platform.end, metrics: metrics).y
                            )
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    guard isPlaying == false, selectedTool == .moving else { return }
                    guard abs(value.translation.width) > 9 || abs(value.translation.height) > 9 else { return }
                    movingDragAction(point(for: value.startLocation, cellSize: metrics.cellSize), point(for: value.location, cellSize: metrics.cellSize))
                }
                .onEnded { value in
                    guard isPlaying == false else { return }

                    if selectedTool == .move && (abs(value.translation.width) > 10 || abs(value.translation.height) > 10) {
                        cameraDragAction(value.translation, metrics.cellSize)
                    } else if selectedTool == .moving && (abs(value.translation.width) > 9 || abs(value.translation.height) > 9) {
                        movingDragAction(point(for: value.startLocation, cellSize: metrics.cellSize), point(for: value.location, cellSize: metrics.cellSize))
                    } else {
                        applyAction(point(for: value.location, cellSize: metrics.cellSize))
                    }
                }
        )
    }

    private func movingPath(_ platform: LevelMovingPlatform, metrics: ViewportMetrics) -> some View {
        let start = pointCenter(platform.start, metrics: metrics)
        let end = pointCenter(platform.end, metrics: metrics)
        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            Color.purplePop.opacity(isPlaying ? 0.32 : 0.72),
            style: StrokeStyle(lineWidth: max(2, metrics.cellSize * 0.12), lineCap: .round, dash: isPlaying ? [6, 8] : [])
        )
    }

    private func point(for location: CGPoint, cellSize: CGFloat) -> LevelGridPoint {
        let column = min(max(Int((location.x / max(cellSize, 1)).rounded(.down)), 0), GameConstants.viewportColumns - 1)
        let row = min(max(Int((location.y / max(cellSize, 1)).rounded(.down)), 0), GameConstants.viewportRows - 1)
        return LevelGridPoint(x: camera.x + column, y: camera.y + row)
    }

    private func pointCenter(_ point: LevelGridPoint, metrics: ViewportMetrics) -> CGPoint {
        CGPoint(
            x: CGFloat(point.x - camera.x) * metrics.cellSize + metrics.cellSize / 2,
            y: CGFloat(point.y - camera.y) * metrics.cellSize + metrics.cellSize / 2
        )
    }

    private func angle(for platform: LevelMovingPlatform) -> Angle {
        let dx = Double(platform.end.x - platform.start.x)
        let dy = Double(platform.end.y - platform.start.y)
        return Angle(radians: atan2(dy, dx))
    }

    private func lineIsVisible(_ platform: LevelMovingPlatform) -> Bool {
        isVisible(point: platform.start) || isVisible(point: platform.end)
    }

    private func isVisible(point: LevelGridPoint) -> Bool {
        point.x >= camera.x - 1 &&
            point.x <= camera.x + GameConstants.viewportColumns &&
            point.y >= camera.y - 1 &&
            point.y <= camera.y + GameConstants.viewportRows
    }

    private func isVisible(x: CGFloat, y: CGFloat) -> Bool {
        x >= CGFloat(camera.x) - 1 &&
            x <= CGFloat(camera.x + GameConstants.viewportColumns + 1) &&
            y >= CGFloat(camera.y) - 1 &&
            y <= CGFloat(camera.y + GameConstants.viewportRows + 1)
    }
}

private struct TileCell: View {
    let point: LevelGridPoint
    let tile: LevelTileKind?
    let isStart: Bool
    let isEnd: Bool
    let hasEnemy: Bool
    let isMoveTool: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(baseFill)
                .overlay(alignment: .bottom) {
                    if tile == .water {
                        Rectangle()
                            .fill(Color.white.opacity(0.13))
                            .frame(height: 3)
                    }
                }

            if let tile = tile {
                Image(systemName: tile.symbolName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(tile.foregroundColor)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
            }

            if isStart {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.mintPop)
            }

            if isEnd {
                Image(systemName: "scope")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.gold)
            }

            if hasEnemy {
                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.redPop)
            }
        }
        .overlay {
            Rectangle()
                .stroke(isMoveTool ? Color.white.opacity(0.16) : Color.white.opacity(0.07), lineWidth: 0.7)
        }
    }

    private var baseFill: Color {
        if let tile = tile {
            return tile.fillColor
        }

        return (point.x + point.y).isMultiple(of: 2)
            ? Color.white.opacity(0.035)
            : Color.white.opacity(0.022)
    }
}

private struct PlayerView: View {
    let facing: CGFloat
    let isInvulnerable: Bool
    let isAttacking: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.mintPop, Color.sky],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(isInvulnerable ? 0.68 : 0.28), lineWidth: 2)
                }

            Circle()
                .fill(Color.black.opacity(0.42))
                .frame(width: 6, height: 6)
                .offset(x: facing >= 0 ? 7 : -7, y: -8)

            if isAttacking {
                Capsule()
                    .fill(Color.gold.opacity(0.9))
                    .frame(width: 30, height: 8)
                    .offset(x: facing >= 0 ? 24 : -24, y: 0)
            }
        }
        .opacity(isInvulnerable ? 0.68 : 1)
    }
}

private struct EnemyView: View {
    let direction: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.redPop, Color.violetSoft],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "exclamationmark")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .offset(x: direction >= 0 ? 2 : -2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct MovingPlatformView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.purplePop, Color(red: 0.55, green: 0.28, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: Color.purplePop.opacity(0.42), radius: 9, y: 4)
    }
}

private struct EditorControls: View {
    @Binding var selectedTool: CreatorTool
    let camera: LevelGridPoint
    let moveCameraAction: (Int, Int) -> Void
    let resetAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CreatorTool.allCases) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: tool.symbolName)
                                    .font(.system(size: 17, weight: .black))
                                Text(tool.title)
                                    .font(.caption2.weight(.black))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .frame(width: 68, height: 54)
                        }
                        .buttonStyle(ToolButtonStyle(tint: tool.tint, isSelected: selectedTool == tool))
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 8) {
                CameraButton(symbol: "arrow.left", action: { moveCameraAction(-2, 0) })
                CameraButton(symbol: "arrow.right", action: { moveCameraAction(2, 0) })
                CameraButton(symbol: "arrow.up", action: { moveCameraAction(0, -1) })
                CameraButton(symbol: "arrow.down", action: { moveCameraAction(0, 1) })

                Text("Camera \(camera.x),\(camera.y)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity)

                Button(action: resetAction) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.black))
                        .frame(height: 36)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct PlayControls: View {
    @Binding var isPressingLeft: Bool
    @Binding var isPressingRight: Bool
    let jumpAction: () -> Void
    let attackAction: () -> Void
    let canAttack: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                HoldButton(symbol: "chevron.left", title: "Left", isPressed: $isPressingLeft)
                HoldButton(symbol: "chevron.right", title: "Right", isPressed: $isPressingRight)
            }

            Spacer(minLength: 8)

            Button(action: jumpAction) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .black))
                    Text("Jump")
                        .font(.caption.weight(.black))
                }
                .frame(width: 76, height: 58)
            }
            .buttonStyle(ActionButtonStyle(tint: Color.mintPop, isEnabled: true))

            Button(action: attackAction) {
                VStack(spacing: 4) {
                    Image(systemName: "burst.fill")
                        .font(.system(size: 20, weight: .black))
                    Text("Attack")
                        .font(.caption.weight(.black))
                }
                .frame(width: 84, height: 58)
            }
            .buttonStyle(ActionButtonStyle(tint: Color.gold, isEnabled: canAttack))
            .disabled(canAttack == false)
        }
        .padding(10)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct HoldButton: View {
    let symbol: String
    let title: String
    @Binding var isPressed: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .black))
            Text(title)
                .font(.caption.weight(.black))
        }
        .foregroundStyle(.white)
        .frame(width: 70, height: 58)
        .background(isPressed ? Color.sky.opacity(0.86) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isPressed ? Color.white.opacity(0.48) : Color.white.opacity(0.13), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isPressed == false {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

private struct CameraButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}

private struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.043, blue: 0.054),
                    Color(red: 0.058, green: 0.083, blue: 0.088),
                    Color(red: 0.026, green: 0.028, blue: 0.036)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 18) {
                ForEach(0..<10, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.035 : 0.018))
                        .frame(height: 1)
                }
            }
            .padding(.horizontal, 18)
        }
        .ignoresSafeArea()
    }
}

private struct ViewportMetrics {
    let cellSize: CGFloat
    let boardWidth: CGFloat
    let boardHeight: CGFloat

    init(availableSize: CGSize) {
        let horizontalCell = availableSize.width / CGFloat(GameConstants.viewportColumns)
        let verticalCell = availableSize.height / CGFloat(GameConstants.viewportRows)
        let size = floor(min(horizontalCell, verticalCell))
        cellSize = max(18, size)
        boardWidth = cellSize * CGFloat(GameConstants.viewportColumns)
        boardHeight = cellSize * CGFloat(GameConstants.viewportRows)
    }
}

private enum GameConstants {
    static let viewportColumns = 18
    static let viewportRows = 11
    static let playerWidth: CGFloat = 0.64
    static let playerHeight: CGFloat = 0.86
    static let platformWidth: CGFloat = 0.96
    static let platformHeight: CGFloat = 0.42
    static let playerSpeed: CGFloat = 5.2
    static let boostSpeed: CGFloat = 9.2
    static let jumpVelocity: CGFloat = 9.2
    static let gravity: CGFloat = 23.0
    static let enemySpeed: CGFloat = 1.7
    static let platformSpeed: CGFloat = 2.4
}

private struct EditableLevel {
    var width = 42
    var height = 16
    var tiles: [LevelGridPoint: LevelTileKind]
    var enemies: Set<LevelGridPoint>
    var movingPlatforms: [LevelMovingPlatform]
    var start: LevelGridPoint
    var end: LevelGridPoint

    static func starter() -> EditableLevel {
        var tiles: [LevelGridPoint: LevelTileKind] = [:]
        for x in 0..<42 {
            tiles[LevelGridPoint(x: x, y: 15)] = .block
        }

        for x in 4...8 {
            tiles[LevelGridPoint(x: x, y: 12)] = .block
        }

        for x in 13...17 {
            tiles[LevelGridPoint(x: x, y: 10)] = .block
        }

        for x in 27...32 {
            tiles[LevelGridPoint(x: x, y: 12)] = .block
        }

        for x in 7...10 {
            tiles[LevelGridPoint(x: x, y: 14)] = .water
        }

        for x in 19...22 {
            tiles[LevelGridPoint(x: x, y: 14)] = .space
        }

        for x in 34...36 {
            tiles[LevelGridPoint(x: x, y: 14)] = .kill
        }

        return EditableLevel(
            tiles: tiles,
            enemies: [
                LevelGridPoint(x: 12, y: 14),
                LevelGridPoint(x: 29, y: 11),
                LevelGridPoint(x: 38, y: 14)
            ],
            movingPlatforms: [
                LevelMovingPlatform(start: LevelGridPoint(x: 22, y: 10), end: LevelGridPoint(x: 26, y: 10))
            ],
            start: LevelGridPoint(x: 2, y: 14),
            end: LevelGridPoint(x: 40, y: 14)
        )
    }

    func contains(_ point: LevelGridPoint) -> Bool {
        point.x >= 0 && point.x < width && point.y >= 0 && point.y < height
    }

    func clamped(_ point: LevelGridPoint) -> LevelGridPoint {
        LevelGridPoint(
            x: min(max(point.x, 0), width - 1),
            y: min(max(point.y, 0), height - 1)
        )
    }

    func isSolid(at point: LevelGridPoint) -> Bool {
        if point.x < 0 || point.x >= width || point.y >= height {
            return true
        }

        if point.y < 0 {
            return false
        }

        return tiles[point] == .block
    }
}

private struct LevelGridPoint: Hashable {
    var x: Int
    var y: Int
}

private struct LevelMovingPlatform: Identifiable, Equatable {
    let id: UUID
    var start: LevelGridPoint
    var end: LevelGridPoint

    init(id: UUID = UUID(), start: LevelGridPoint, end: LevelGridPoint) {
        self.id = id
        self.start = start
        self.end = end
    }

    func touches(_ point: LevelGridPoint) -> Bool {
        start == point || end == point
    }
}

private enum LevelTileKind: Equatable {
    case block
    case kill
    case water
    case space

    var symbolName: String {
        switch self {
        case .block:
            return "square.grid.3x3.fill"
        case .kill:
            return "xmark.octagon.fill"
        case .water:
            return "drop.fill"
        case .space:
            return "bolt.fill"
        }
    }

    var fillColor: Color {
        switch self {
        case .block:
            return Color(red: 0.34, green: 0.37, blue: 0.39)
        case .kill:
            return Color(red: 0.55, green: 0.05, blue: 0.09)
        case .water:
            return Color(red: 0.08, green: 0.48, blue: 0.72)
        case .space:
            return Color(red: 0.78, green: 0.56, blue: 0.16)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .block:
            return Color.white.opacity(0.68)
        case .kill:
            return Color(red: 1.0, green: 0.42, blue: 0.46)
        case .water:
            return Color(red: 0.72, green: 0.95, blue: 1.0)
        case .space:
            return Color(red: 1.0, green: 0.96, blue: 0.62)
        }
    }
}

private enum CreatorTool: String, CaseIterable, Identifiable, Equatable {
    case block
    case kill
    case water
    case space
    case moving
    case enemy
    case start
    case end
    case delete
    case move

    var id: String { rawValue }

    var title: String {
        switch self {
        case .block:
            return "Block"
        case .kill:
            return "Kill"
        case .water:
            return "Water"
        case .space:
            return "Space"
        case .moving:
            return "Moving"
        case .enemy:
            return "Enemy"
        case .start:
            return "Start"
        case .end:
            return "End"
        case .delete:
            return "Delete"
        case .move:
            return "Move"
        }
    }

    var hint: String {
        switch self {
        case .moving:
            return "Drag from a purple block to set its arrow path."
        case .kill:
            return "Kill blocks respawn the player on touch."
        case .move:
            return "Drag the board or use arrows to move the camera."
        default:
            return "Tap tiles to build, then press Play."
        }
    }

    var symbolName: String {
        switch self {
        case .block:
            return "square.grid.3x3.fill"
        case .kill:
            return "xmark.octagon.fill"
        case .water:
            return "drop.fill"
        case .space:
            return "bolt.fill"
        case .moving:
            return "arrow.left.and.right.square.fill"
        case .enemy:
            return "exclamationmark.triangle.fill"
        case .start:
            return "flag.fill"
        case .end:
            return "scope"
        case .delete:
            return "trash.fill"
        case .move:
            return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    var tint: Color {
        switch self {
        case .block:
            return Color(red: 0.78, green: 0.82, blue: 0.86)
        case .kill:
            return Color.redPop
        case .water:
            return Color(red: 0.34, green: 0.78, blue: 1.0)
        case .space:
            return Color.gold
        case .moving:
            return Color.purplePop
        case .enemy:
            return Color(red: 1.0, green: 0.44, blue: 0.5)
        case .start:
            return Color.mintPop
        case .end:
            return Color.gold
        case .delete:
            return Color(red: 1.0, green: 0.42, blue: 0.46)
        case .move:
            return Color(red: 0.72, green: 0.8, blue: 1.0)
        }
    }
}

private struct LevelPlayState {
    var playerX: CGFloat
    var playerY: CGFloat
    var velocityX: CGFloat = 0
    var velocityY: CGFloat = 0
    var facing: CGFloat = 1
    var health = 3
    var isGrounded = false
    var attackCooldown: CGFloat = 0
    var attackFlash: CGFloat = 0
    var invulnerability: CGFloat = 0
    var enemies: [LevelEnemyState]
    var platforms: [LevelMovingPlatformState]
    var isComplete = false
    var statusText = "Reach the End"

    init(level: EditableLevel) {
        playerX = CGFloat(level.start.x) + 0.5
        playerY = CGFloat(level.start.y) + 0.38
        enemies = level.enemies
            .sorted { lhs, rhs in
                lhs.y == rhs.y ? lhs.x < rhs.x : lhs.y < rhs.y
            }
            .map { LevelEnemyState(point: $0) }
        platforms = level.movingPlatforms.map { LevelMovingPlatformState(platform: $0) }
    }
}

private struct LevelEnemyState: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var direction: CGFloat

    init(point: LevelGridPoint) {
        x = CGFloat(point.x) + 0.5
        y = CGFloat(point.y) + 0.45
        direction = point.x.isMultiple(of: 2) ? 1 : -1
    }
}

private struct LevelMovingPlatformState: Identifiable {
    let id: UUID
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    var progress: CGFloat = 0
    var direction: CGFloat = 1
    var previousX: CGFloat
    var previousY: CGFloat
    var x: CGFloat
    var y: CGFloat

    init(platform: LevelMovingPlatform) {
        id = platform.id
        startX = CGFloat(platform.start.x) + 0.5
        startY = CGFloat(platform.start.y) + 0.5
        endX = CGFloat(platform.end.x) + 0.5
        endY = CGFloat(platform.end.y) + 0.5
        previousX = startX
        previousY = startY
        x = startX
        y = startY
    }

    var deltaX: CGFloat { x - previousX }
    var deltaY: CGFloat { y - previousY }

    var collisionRect: CGRect {
        CGRect(
            x: x - GameConstants.platformWidth / 2,
            y: y - GameConstants.platformHeight / 2,
            width: GameConstants.platformWidth,
            height: GameConstants.platformHeight
        )
    }

    mutating func advance(deltaTime: CGFloat) {
        previousX = x
        previousY = y

        let deltaX = endX - startX
        let deltaY = endY - startY
        let distance = max(sqrt(deltaX * deltaX + deltaY * deltaY), 0.5)
        progress += direction * GameConstants.platformSpeed * deltaTime / distance
        if progress >= 1 {
            progress = 1
            direction = -1
        } else if progress <= 0 {
            progress = 0
            direction = 1
        }

        x = startX + (endX - startX) * progress
        y = startY + (endY - startY) * progress
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .background(
                isActive
                    ? Color.mintPop
                    : Color.white.opacity(configuration.isPressed ? 0.16 : 0.09),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 0.36 : 0.14), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct ToolButtonStyle: ButtonStyle {
    let tint: Color
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.black : tint)
            .background(
                isSelected
                    ? tint
                    : Color.white.opacity(configuration.isPressed ? 0.14 : 0.075),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.38) : tint.opacity(0.24), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct ActionButtonStyle: ButtonStyle {
    let tint: Color
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.46))
            .background(
                isEnabled
                    ? tint.opacity(configuration.isPressed ? 0.78 : 0.96)
                    : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.35 : 0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
    }
}

private extension Color {
    static let mintPop = Color(red: 0.58, green: 0.9, blue: 0.67)
    static let sky = Color(red: 0.42, green: 0.76, blue: 0.96)
    static let gold = Color(red: 1.0, green: 0.76, blue: 0.28)
    static let redPop = Color(red: 1.0, green: 0.34, blue: 0.4)
    static let purplePop = Color(red: 0.78, green: 0.48, blue: 1.0)
    static let violetSoft = Color(red: 0.72, green: 0.44, blue: 0.96)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
