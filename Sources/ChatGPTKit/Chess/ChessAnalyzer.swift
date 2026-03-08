import Foundation

public struct ChessAnalysis {
    public let bestMove: ChessMove?
    public let evaluation: Int
    public let principalVariation: [ChessMove]

    public init(bestMove: ChessMove?, evaluation: Int, principalVariation: [ChessMove]) {
        self.bestMove = bestMove
        self.evaluation = evaluation
        self.principalVariation = principalVariation
    }
}

public struct MoveReview {
    public let playedMove: ChessMove
    public let evaluationAfterMove: Int
    public let suggestedReply: ChessMove?

    public init(playedMove: ChessMove, evaluationAfterMove: Int, suggestedReply: ChessMove?) {
        self.playedMove = playedMove
        self.evaluationAfterMove = evaluationAfterMove
        self.suggestedReply = suggestedReply
    }
}

public final class ChessGameAnalyzer {
    public private(set) var board: ChessBoard

    public init(board: ChessBoard = ChessBoard()) {
        self.board = board
    }

    public func suggestBestMove(depth: Int = 3) -> ChessAnalysis {
        let depth = max(1, depth)
        let side = board.sideToMove
        let result = negamax(board: board, depth: depth, alpha: -1_000_000, beta: 1_000_000, perspective: side)
        return ChessAnalysis(bestMove: result.bestMove, evaluation: result.score, principalVariation: result.pv)
    }

    @discardableResult
    public func recordMove(_ uciMove: String, depth: Int = 3) throws -> MoveReview {
        guard let move = ChessMove(uci: uciMove) else {
            throw ChessEngineError.illegalMove("Invalid move format: \(uciMove)")
        }
        try board.apply(move: move)

        let postMoveEvaluation = board.evaluateMaterialAndMobility(for: board.sideToMove)
        let suggestion = suggestBestMove(depth: depth)
        return MoveReview(
            playedMove: move,
            evaluationAfterMove: postMoveEvaluation,
            suggestedReply: suggestion.bestMove
        )
    }

    private func negamax(
        board: ChessBoard,
        depth: Int,
        alpha: Int,
        beta: Int,
        perspective: ChessColor
    ) -> (score: Int, bestMove: ChessMove?, pv: [ChessMove]) {
        var alpha = alpha
        let moves = board.legalMoves()

        if depth == 0 || moves.isEmpty {
            switch board.gameState() {
            case .checkmate(let winner):
                return (winner == perspective ? 900_000 : -900_000, nil, [])
            case .stalemate:
                return (0, nil, [])
            case .inProgress:
                return (board.evaluateMaterialAndMobility(for: perspective), nil, [])
            }
        }

        var bestScore = -1_000_000
        var bestMove: ChessMove?
        var bestPV = [ChessMove]()

        for move in moves {
            var next = board
            next.makeUncheckedMove(move)

            let child = negamax(
                board: next,
                depth: depth - 1,
                alpha: -beta,
                beta: -alpha,
                perspective: perspective
            )
            let score = -child.score

            if score > bestScore {
                bestScore = score
                bestMove = move
                bestPV = [move] + child.pv
            }

            alpha = max(alpha, score)
            if alpha >= beta {
                break
            }
        }

        return (bestScore, bestMove, bestPV)
    }
}
