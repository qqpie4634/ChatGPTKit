import Foundation

public enum ChessColor: String {
    case white
    case black

    var opponent: ChessColor {
        self == .white ? .black : .white
    }
}

public enum PieceType: String {
    case pawn
    case knight
    case bishop
    case rook
    case queen
    case king

    var materialValue: Int {
        switch self {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 20_000
        }
    }
}

public struct ChessPiece: Equatable {
    public let color: ChessColor
    public let type: PieceType

    public init(color: ChessColor, type: PieceType) {
        self.color = color
        self.type = type
    }
}

public struct ChessSquare: Hashable, Equatable {
    public let file: Int
    public let rank: Int

    public init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    public init?(algebraic: String) {
        guard algebraic.count == 2 else { return nil }
        let chars = Array(algebraic.lowercased())
        guard let fileValue = "abcdefgh".firstIndex(of: chars[0]), let rankValue = Int(String(chars[1])) else {
            return nil
        }
        let fileDistance = "abcdefgh".distance(from: "abcdefgh".startIndex, to: fileValue)
        let rankIndex = rankValue - 1
        guard (0...7).contains(fileDistance), (0...7).contains(rankIndex) else { return nil }
        self.init(file: fileDistance, rank: rankIndex)
    }

    public var algebraic: String {
        let fileChar = Array("abcdefgh")[file]
        return "\(fileChar)\(rank + 1)"
    }

    var isValid: Bool {
        (0...7).contains(file) && (0...7).contains(rank)
    }
}

public struct ChessMove: Equatable {
    public let from: ChessSquare
    public let to: ChessSquare
    public let promotion: PieceType?

    public init(from: ChessSquare, to: ChessSquare, promotion: PieceType? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    public init?(uci: String) {
        let input = uci.lowercased()
        guard input.count == 4 || input.count == 5 else { return nil }
        let chars = Array(input)
        guard
            let from = ChessSquare(algebraic: String(chars[0...1])),
            let to = ChessSquare(algebraic: String(chars[2...3]))
        else {
            return nil
        }

        var promotion: PieceType?
        if input.count == 5 {
            switch chars[4] {
            case "q": promotion = .queen
            case "r": promotion = .rook
            case "b": promotion = .bishop
            case "n": promotion = .knight
            default: return nil
            }
        }

        self.init(from: from, to: to, promotion: promotion)
    }

    public var uci: String {
        let promotionSuffix: String
        switch promotion {
        case .queen: promotionSuffix = "q"
        case .rook: promotionSuffix = "r"
        case .bishop: promotionSuffix = "b"
        case .knight: promotionSuffix = "n"
        default: promotionSuffix = ""
        }
        return "\(from.algebraic)\(to.algebraic)\(promotionSuffix)"
    }
}

public enum ChessGameState: Equatable {
    case inProgress
    case checkmate(winner: ChessColor)
    case stalemate
}

public enum ChessEngineError: Error {
    case illegalMove(String)
}

public struct ChessBoard: Equatable {
    private var squares: [ChessPiece?]
    public private(set) var sideToMove: ChessColor

    public init() {
        self.squares = Array(repeating: nil, count: 64)
        self.sideToMove = .white
        setupInitialPosition()
    }

    private init(squares: [ChessPiece?], sideToMove: ChessColor) {
        self.squares = squares
        self.sideToMove = sideToMove
    }

    public func piece(at square: ChessSquare) -> ChessPiece? {
        guard square.isValid else { return nil }
        return squares[square.rank * 8 + square.file]
    }

    public func legalMoves() -> [ChessMove] {
        legalMoves(for: sideToMove)
    }

    public func legalMoves(for color: ChessColor) -> [ChessMove] {
        var candidates = [ChessMove]()
        for rank in 0...7 {
            for file in 0...7 {
                let from = ChessSquare(file: file, rank: rank)
                guard let piece = piece(at: from), piece.color == color else { continue }
                candidates.append(contentsOf: pseudoLegalMoves(for: piece, from: from))
            }
        }

        return candidates.filter { move in
            var next = self
            next.makeUncheckedMove(move)
            return !next.isInCheck(color: color)
        }
    }

    public func isInCheck(color: ChessColor) -> Bool {
        guard let kingSquare = kingSquare(for: color) else { return false }
        return isSquareAttacked(kingSquare, by: color.opponent)
    }

    public func gameState() -> ChessGameState {
        let moves = legalMoves()
        if !moves.isEmpty { return .inProgress }
        if isInCheck(color: sideToMove) {
            return .checkmate(winner: sideToMove.opponent)
        }
        return .stalemate
    }

    public mutating func apply(move: ChessMove) throws {
        let legal = legalMoves()
        guard legal.contains(where: { $0 == move }) else {
            throw ChessEngineError.illegalMove("Illegal move: \(move.uci)")
        }
        makeUncheckedMove(move)
    }

    func evaluateMaterialAndMobility(for perspective: ChessColor) -> Int {
        var materialScore = 0
        for square in squares {
            guard let piece = square else { continue }
            let sign = piece.color == perspective ? 1 : -1
            materialScore += piece.type.materialValue * sign
        }

        let ownMobility = legalMoves(for: perspective).count
        let enemyMobility = legalMoves(for: perspective.opponent).count
        let mobilityScore = (ownMobility - enemyMobility) * 3
        return materialScore + mobilityScore
    }

    mutating func makeUncheckedMove(_ move: ChessMove) {
        guard let movingPiece = piece(at: move.from) else { return }
        setPiece(nil, at: move.from)

        var pieceToPlace = movingPiece
        if movingPiece.type == .pawn {
            let targetRank = move.to.rank
            if targetRank == 0 || targetRank == 7 {
                pieceToPlace = ChessPiece(color: movingPiece.color, type: move.promotion ?? .queen)
            }
        }

        setPiece(pieceToPlace, at: move.to)
        sideToMove = sideToMove.opponent
    }

    private mutating func setupInitialPosition() {
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]

        for file in 0...7 {
            setPiece(ChessPiece(color: .white, type: .pawn), at: ChessSquare(file: file, rank: 1))
            setPiece(ChessPiece(color: .black, type: .pawn), at: ChessSquare(file: file, rank: 6))
            setPiece(ChessPiece(color: .white, type: backRank[file]), at: ChessSquare(file: file, rank: 0))
            setPiece(ChessPiece(color: .black, type: backRank[file]), at: ChessSquare(file: file, rank: 7))
        }
    }

    private mutating func setPiece(_ piece: ChessPiece?, at square: ChessSquare) {
        squares[square.rank * 8 + square.file] = piece
    }

    private func kingSquare(for color: ChessColor) -> ChessSquare? {
        for rank in 0...7 {
            for file in 0...7 {
                let square = ChessSquare(file: file, rank: rank)
                if let piece = piece(at: square), piece.color == color, piece.type == .king {
                    return square
                }
            }
        }
        return nil
    }

    private func isSquareAttacked(_ target: ChessSquare, by attackerColor: ChessColor) -> Bool {
        for rank in 0...7 {
            for file in 0...7 {
                let from = ChessSquare(file: file, rank: rank)
                guard let piece = piece(at: from), piece.color == attackerColor else { continue }
                let attacks = attackSquares(for: piece, from: from)
                if attacks.contains(target) {
                    return true
                }
            }
        }
        return false
    }

    private func attackSquares(for piece: ChessPiece, from square: ChessSquare) -> [ChessSquare] {
        switch piece.type {
        case .pawn:
            let direction = piece.color == .white ? 1 : -1
            return [
                ChessSquare(file: square.file - 1, rank: square.rank + direction),
                ChessSquare(file: square.file + 1, rank: square.rank + direction)
            ].filter { $0.isValid }
        case .knight:
            return knightJumps(from: square)
        case .bishop:
            return raySquares(from: square, deltas: [(1, 1), (-1, 1), (1, -1), (-1, -1)])
        case .rook:
            return raySquares(from: square, deltas: [(1, 0), (-1, 0), (0, 1), (0, -1)])
        case .queen:
            return raySquares(from: square, deltas: [
                (1, 0), (-1, 0), (0, 1), (0, -1),
                (1, 1), (-1, 1), (1, -1), (-1, -1)
            ])
        case .king:
            return kingNeighbors(from: square)
        }
    }

    private func pseudoLegalMoves(for piece: ChessPiece, from square: ChessSquare) -> [ChessMove] {
        switch piece.type {
        case .pawn:
            return pawnMoves(for: piece.color, from: square)
        case .knight:
            return jumpsMoves(from: square, offsets: [
                (-2, -1), (-2, 1), (-1, -2), (-1, 2),
                (1, -2), (1, 2), (2, -1), (2, 1)
            ])
        case .bishop:
            return rayMoves(from: square, deltas: [(1, 1), (-1, 1), (1, -1), (-1, -1)])
        case .rook:
            return rayMoves(from: square, deltas: [(1, 0), (-1, 0), (0, 1), (0, -1)])
        case .queen:
            return rayMoves(from: square, deltas: [
                (1, 0), (-1, 0), (0, 1), (0, -1),
                (1, 1), (-1, 1), (1, -1), (-1, -1)
            ])
        case .king:
            return kingNeighbors(from: square).compactMap { target in
                guard let targetPiece = self.piece(at: target), targetPiece.color == piece.color else {
                    return ChessMove(from: square, to: target)
                }
                return nil
            }
        }
    }

    private func pawnMoves(for color: ChessColor, from square: ChessSquare) -> [ChessMove] {
        let direction = color == .white ? 1 : -1
        let startRank = color == .white ? 1 : 6
        var moves = [ChessMove]()

        let oneStep = ChessSquare(file: square.file, rank: square.rank + direction)
        if oneStep.isValid, piece(at: oneStep) == nil {
            moves.append(contentsOf: pawnAdvanceMoves(from: square, to: oneStep))

            let twoStep = ChessSquare(file: square.file, rank: square.rank + 2 * direction)
            if square.rank == startRank, piece(at: twoStep) == nil {
                moves.append(ChessMove(from: square, to: twoStep))
            }
        }

        for captureFile in [square.file - 1, square.file + 1] {
            let captureSquare = ChessSquare(file: captureFile, rank: square.rank + direction)
            guard captureSquare.isValid, let target = piece(at: captureSquare), target.color != color else {
                continue
            }
            moves.append(contentsOf: pawnAdvanceMoves(from: square, to: captureSquare))
        }

        return moves
    }

    private func pawnAdvanceMoves(from: ChessSquare, to: ChessSquare) -> [ChessMove] {
        if to.rank == 0 || to.rank == 7 {
            return [
                ChessMove(from: from, to: to, promotion: .queen),
                ChessMove(from: from, to: to, promotion: .rook),
                ChessMove(from: from, to: to, promotion: .bishop),
                ChessMove(from: from, to: to, promotion: .knight)
            ]
        }
        return [ChessMove(from: from, to: to)]
    }

    private func jumpsMoves(from square: ChessSquare, offsets: [(Int, Int)]) -> [ChessMove] {
        offsets.compactMap { delta in
            let target = ChessSquare(file: square.file + delta.0, rank: square.rank + delta.1)
            guard target.isValid else { return nil }
            if let targetPiece = piece(at: target), targetPiece.color == piece(at: square)?.color {
                return nil
            }
            return ChessMove(from: square, to: target)
        }
    }

    private func rayMoves(from square: ChessSquare, deltas: [(Int, Int)]) -> [ChessMove] {
        var moves = [ChessMove]()
        guard let movingColor = piece(at: square)?.color else { return moves }

        for delta in deltas {
            var current = ChessSquare(file: square.file + delta.0, rank: square.rank + delta.1)
            while current.isValid {
                if let target = piece(at: current) {
                    if target.color != movingColor {
                        moves.append(ChessMove(from: square, to: current))
                    }
                    break
                }
                moves.append(ChessMove(from: square, to: current))
                current = ChessSquare(file: current.file + delta.0, rank: current.rank + delta.1)
            }
        }

        return moves
    }

    private func raySquares(from square: ChessSquare, deltas: [(Int, Int)]) -> [ChessSquare] {
        var result = [ChessSquare]()

        for delta in deltas {
            var current = ChessSquare(file: square.file + delta.0, rank: square.rank + delta.1)
            while current.isValid {
                result.append(current)
                if piece(at: current) != nil {
                    break
                }
                current = ChessSquare(file: current.file + delta.0, rank: current.rank + delta.1)
            }
        }

        return result
    }

    private func kingNeighbors(from square: ChessSquare) -> [ChessSquare] {
        var result = [ChessSquare]()
        for fileDelta in -1...1 {
            for rankDelta in -1...1 {
                if fileDelta == 0 && rankDelta == 0 { continue }
                let target = ChessSquare(file: square.file + fileDelta, rank: square.rank + rankDelta)
                if target.isValid {
                    result.append(target)
                }
            }
        }
        return result
    }

    private func knightJumps(from square: ChessSquare) -> [ChessSquare] {
        [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ].map {
            ChessSquare(file: square.file + $0.0, rank: square.rank + $0.1)
        }.filter { $0.isValid }
    }
}
