import unittest

from python_chesscli.chesscli import Analyzer, Board, Move, Piece, PieceType, Color, Square


class ChessCLITests(unittest.TestCase):
    def test_initial_has_20_moves(self):
        board = Board()
        self.assertEqual(len(board.legal_moves()), 20)

    def test_apply_e2e4(self):
        board = Board()
        move = Move.from_uci("e2e4")
        self.assertIsNotNone(move)
        board.apply(move)
        self.assertIsNone(board.piece_at(Square(4, 1)))
        self.assertEqual(board.piece_at(Square(4, 3)), Piece(Color.WHITE, PieceType.PAWN))
        self.assertEqual(board.side_to_move, Color.BLACK)

    def test_analyzer_suggests(self):
        analyzer = Analyzer()
        analysis = analyzer.suggest(depth=2)
        self.assertIsNotNone(analysis.best_move)
        self.assertTrue(len(analysis.pv) > 0)


if __name__ == "__main__":
    unittest.main()
