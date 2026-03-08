import XCTest
@testable import ChatGPTKit

final class ChessAnalyzerTests: XCTestCase {
    func testInitialPositionHasTwentyLegalMoves() {
        let board = ChessBoard()
        XCTAssertEqual(board.legalMoves().count, 20)
    }

    func testApplyMoveE2E4() throws {
        var board = ChessBoard()
        let move = try XCTUnwrap(ChessMove(uci: "e2e4"))

        try board.apply(move: move)

        XCTAssertNil(board.piece(at: ChessSquare(file: 4, rank: 1)))
        let movedPiece = board.piece(at: ChessSquare(file: 4, rank: 3))
        XCTAssertEqual(movedPiece, ChessPiece(color: .white, type: .pawn))
        XCTAssertEqual(board.sideToMove, .black)
    }

    func testAnalyzerSuggestsMove() {
        let analyzer = ChessGameAnalyzer()
        let analysis = analyzer.suggestBestMove(depth: 2)

        XCTAssertNotNil(analysis.bestMove)
        XCTAssertFalse(analysis.principalVariation.isEmpty)
    }
}
