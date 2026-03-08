from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import List, Optional, Tuple


class Color(str, Enum):
    WHITE = "white"
    BLACK = "black"

    @property
    def opponent(self) -> "Color":
        return Color.BLACK if self == Color.WHITE else Color.WHITE


class PieceType(str, Enum):
    PAWN = "pawn"
    KNIGHT = "knight"
    BISHOP = "bishop"
    ROOK = "rook"
    QUEEN = "queen"
    KING = "king"

    @property
    def value(self) -> int:
        return {
            PieceType.PAWN: 100,
            PieceType.KNIGHT: 320,
            PieceType.BISHOP: 330,
            PieceType.ROOK: 500,
            PieceType.QUEEN: 900,
            PieceType.KING: 20_000,
        }[self]


@dataclass(frozen=True)
class Piece:
    color: Color
    kind: PieceType


@dataclass(frozen=True)
class Square:
    file: int
    rank: int

    @property
    def valid(self) -> bool:
        return 0 <= self.file <= 7 and 0 <= self.rank <= 7

    @property
    def algebraic(self) -> str:
        return f"{'abcdefgh'[self.file]}{self.rank + 1}"

    @staticmethod
    def from_algebraic(text: str) -> Optional["Square"]:
        if len(text) != 2:
            return None
        f, r = text[0].lower(), text[1]
        if f not in "abcdefgh" or not r.isdigit():
            return None
        sq = Square("abcdefgh".index(f), int(r) - 1)
        return sq if sq.valid else None


@dataclass(frozen=True)
class Move:
    from_sq: Square
    to_sq: Square
    promotion: Optional[PieceType] = None

    @property
    def uci(self) -> str:
        promo = {
            PieceType.QUEEN: "q",
            PieceType.ROOK: "r",
            PieceType.BISHOP: "b",
            PieceType.KNIGHT: "n",
        }.get(self.promotion, "")
        return f"{self.from_sq.algebraic}{self.to_sq.algebraic}{promo}"

    @staticmethod
    def from_uci(text: str) -> Optional["Move"]:
        text = text.lower().strip()
        if len(text) not in (4, 5):
            return None
        from_sq = Square.from_algebraic(text[:2])
        to_sq = Square.from_algebraic(text[2:4])
        if not from_sq or not to_sq:
            return None
        promo = None
        if len(text) == 5:
            promo = {
                "q": PieceType.QUEEN,
                "r": PieceType.ROOK,
                "b": PieceType.BISHOP,
                "n": PieceType.KNIGHT,
            }.get(text[4])
            if promo is None:
                return None
        return Move(from_sq, to_sq, promo)


class Board:
    def __init__(self) -> None:
        self.squares: List[Optional[Piece]] = [None] * 64
        self.side_to_move = Color.WHITE
        self._setup()

    def clone(self) -> "Board":
        b = Board.__new__(Board)
        b.squares = self.squares.copy()
        b.side_to_move = self.side_to_move
        return b

    def idx(self, sq: Square) -> int:
        return sq.rank * 8 + sq.file

    def piece_at(self, sq: Square) -> Optional[Piece]:
        return self.squares[self.idx(sq)] if sq.valid else None

    def set_piece(self, sq: Square, piece: Optional[Piece]) -> None:
        self.squares[self.idx(sq)] = piece

    def _setup(self) -> None:
        back = [
            PieceType.ROOK,
            PieceType.KNIGHT,
            PieceType.BISHOP,
            PieceType.QUEEN,
            PieceType.KING,
            PieceType.BISHOP,
            PieceType.KNIGHT,
            PieceType.ROOK,
        ]
        for f in range(8):
            self.set_piece(Square(f, 1), Piece(Color.WHITE, PieceType.PAWN))
            self.set_piece(Square(f, 6), Piece(Color.BLACK, PieceType.PAWN))
            self.set_piece(Square(f, 0), Piece(Color.WHITE, back[f]))
            self.set_piece(Square(f, 7), Piece(Color.BLACK, back[f]))

    def legal_moves(self, color: Optional[Color] = None) -> List[Move]:
        color = color or self.side_to_move
        candidates: List[Move] = []
        for r in range(8):
            for f in range(8):
                sq = Square(f, r)
                p = self.piece_at(sq)
                if p and p.color == color:
                    candidates.extend(self._pseudo_moves(p, sq))
        legal = []
        for m in candidates:
            b = self.clone()
            b.make_unchecked(m)
            if not b.in_check(color):
                legal.append(m)
        return legal

    def apply(self, move: Move) -> None:
        if move not in self.legal_moves():
            raise ValueError(f"Illegal move: {move.uci}")
        self.make_unchecked(move)

    def make_unchecked(self, move: Move) -> None:
        piece = self.piece_at(move.from_sq)
        if not piece:
            return
        self.set_piece(move.from_sq, None)
        placed = piece
        if piece.kind == PieceType.PAWN and move.to_sq.rank in (0, 7):
            placed = Piece(piece.color, move.promotion or PieceType.QUEEN)
        self.set_piece(move.to_sq, placed)
        self.side_to_move = self.side_to_move.opponent

    def in_check(self, color: Color) -> bool:
        king = self._king_square(color)
        if not king:
            return False
        return self._attacked(king, color.opponent)

    def state(self) -> str:
        moves = self.legal_moves()
        if moves:
            return "in_progress"
        return "checkmate" if self.in_check(self.side_to_move) else "stalemate"

    def evaluate(self, perspective: Color) -> int:
        score = 0
        for p in self.squares:
            if not p:
                continue
            score += p.kind.value if p.color == perspective else -p.kind.value
        score += (len(self.legal_moves(perspective)) - len(self.legal_moves(perspective.opponent))) * 3
        return score

    def _king_square(self, color: Color) -> Optional[Square]:
        for r in range(8):
            for f in range(8):
                sq = Square(f, r)
                p = self.piece_at(sq)
                if p and p.color == color and p.kind == PieceType.KING:
                    return sq
        return None

    def _attacked(self, target: Square, by: Color) -> bool:
        for r in range(8):
            for f in range(8):
                sq = Square(f, r)
                p = self.piece_at(sq)
                if p and p.color == by and target in self._attack_squares(p, sq):
                    return True
        return False

    def _attack_squares(self, p: Piece, sq: Square) -> List[Square]:
        if p.kind == PieceType.PAWN:
            d = 1 if p.color == Color.WHITE else -1
            return [s for s in [Square(sq.file - 1, sq.rank + d), Square(sq.file + 1, sq.rank + d)] if s.valid]
        if p.kind == PieceType.KNIGHT:
            return self._knight(sq)
        if p.kind == PieceType.BISHOP:
            return self._rays(sq, [(1, 1), (-1, 1), (1, -1), (-1, -1)])
        if p.kind == PieceType.ROOK:
            return self._rays(sq, [(1, 0), (-1, 0), (0, 1), (0, -1)])
        if p.kind == PieceType.QUEEN:
            return self._rays(sq, [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)])
        return self._king(sq)

    def _pseudo_moves(self, p: Piece, sq: Square) -> List[Move]:
        if p.kind == PieceType.PAWN:
            return self._pawn_moves(p.color, sq)
        if p.kind == PieceType.KNIGHT:
            return self._jump_moves(sq, [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)])
        if p.kind == PieceType.BISHOP:
            return self._ray_moves(sq, [(1, 1), (-1, 1), (1, -1), (-1, -1)])
        if p.kind == PieceType.ROOK:
            return self._ray_moves(sq, [(1, 0), (-1, 0), (0, 1), (0, -1)])
        if p.kind == PieceType.QUEEN:
            return self._ray_moves(sq, [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)])
        out = []
        for t in self._king(sq):
            tp = self.piece_at(t)
            if not tp or tp.color != p.color:
                out.append(Move(sq, t))
        return out

    def _pawn_moves(self, color: Color, sq: Square) -> List[Move]:
        d = 1 if color == Color.WHITE else -1
        start = 1 if color == Color.WHITE else 6
        moves: List[Move] = []
        one = Square(sq.file, sq.rank + d)
        if one.valid and self.piece_at(one) is None:
            moves.extend(self._promotion_variants(sq, one))
            two = Square(sq.file, sq.rank + d * 2)
            if sq.rank == start and self.piece_at(two) is None:
                moves.append(Move(sq, two))
        for cf in (sq.file - 1, sq.file + 1):
            cap = Square(cf, sq.rank + d)
            tp = self.piece_at(cap) if cap.valid else None
            if tp and tp.color != color:
                moves.extend(self._promotion_variants(sq, cap))
        return moves

    def _promotion_variants(self, from_sq: Square, to_sq: Square) -> List[Move]:
        if to_sq.rank in (0, 7):
            return [Move(from_sq, to_sq, p) for p in (PieceType.QUEEN, PieceType.ROOK, PieceType.BISHOP, PieceType.KNIGHT)]
        return [Move(from_sq, to_sq)]

    def _jump_moves(self, sq: Square, offsets: List[Tuple[int, int]]) -> List[Move]:
        color = self.piece_at(sq).color
        out = []
        for df, dr in offsets:
            t = Square(sq.file + df, sq.rank + dr)
            if not t.valid:
                continue
            tp = self.piece_at(t)
            if not tp or tp.color != color:
                out.append(Move(sq, t))
        return out

    def _ray_moves(self, sq: Square, deltas: List[Tuple[int, int]]) -> List[Move]:
        color = self.piece_at(sq).color
        out: List[Move] = []
        for df, dr in deltas:
            t = Square(sq.file + df, sq.rank + dr)
            while t.valid:
                tp = self.piece_at(t)
                if tp:
                    if tp.color != color:
                        out.append(Move(sq, t))
                    break
                out.append(Move(sq, t))
                t = Square(t.file + df, t.rank + dr)
        return out

    def _rays(self, sq: Square, deltas: List[Tuple[int, int]]) -> List[Square]:
        out: List[Square] = []
        for df, dr in deltas:
            t = Square(sq.file + df, sq.rank + dr)
            while t.valid:
                out.append(t)
                if self.piece_at(t):
                    break
                t = Square(t.file + df, t.rank + dr)
        return out

    def _king(self, sq: Square) -> List[Square]:
        out = []
        for df in (-1, 0, 1):
            for dr in (-1, 0, 1):
                if df == 0 and dr == 0:
                    continue
                t = Square(sq.file + df, sq.rank + dr)
                if t.valid:
                    out.append(t)
        return out

    def _knight(self, sq: Square) -> List[Square]:
        return [
            t
            for t in [Square(sq.file + df, sq.rank + dr) for df, dr in [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]]
            if t.valid
        ]


@dataclass
class Analysis:
    best_move: Optional[Move]
    evaluation: int
    pv: List[Move]


class Analyzer:
    def __init__(self) -> None:
        self.board = Board()

    def suggest(self, depth: int = 3) -> Analysis:
        side = self.board.side_to_move
        score, best, pv = self._negamax(self.board, max(1, depth), -1_000_000, 1_000_000, side)
        return Analysis(best, score, pv)

    def record(self, uci: str, depth: int = 3) -> Tuple[Move, int, Optional[Move]]:
        m = Move.from_uci(uci)
        if m is None:
            raise ValueError(f"Invalid move format: {uci}")
        self.board.apply(m)
        eval_after = self.board.evaluate(self.board.side_to_move)
        suggestion = self.suggest(depth).best_move
        return m, eval_after, suggestion

    def _negamax(self, board: Board, depth: int, alpha: int, beta: int, perspective: Color) -> Tuple[int, Optional[Move], List[Move]]:
        moves = board.legal_moves()
        if depth == 0 or not moves:
            state = board.state()
            if state == "checkmate":
                winner = board.side_to_move.opponent
                return (900_000 if winner == perspective else -900_000, None, [])
            if state == "stalemate":
                return (0, None, [])
            return board.evaluate(perspective), None, []

        best_score = -1_000_000
        best_move: Optional[Move] = None
        best_pv: List[Move] = []

        for m in moves:
            nxt = board.clone()
            nxt.make_unchecked(m)
            child_score, _, child_pv = self._negamax(nxt, depth - 1, -beta, -alpha, perspective)
            score = -child_score
            if score > best_score:
                best_score = score
                best_move = m
                best_pv = [m] + child_pv
            alpha = max(alpha, score)
            if alpha >= beta:
                break
        return best_score, best_move, best_pv


def run_cli() -> None:
    analyzer = Analyzer()
    print("歡迎使用 Python ChessCLI")
    print("指令：move <uci> [depth] | best [depth] | state | help | quit")

    while True:
        raw = input("\n> ").strip()
        if not raw:
            continue
        parts = raw.split()
        cmd = parts[0].lower()

        if cmd in ("quit", "exit"):
            print("再見！")
            break
        if cmd == "help":
            print("move <uci> [depth]：輸入一步棋並分析")
            print("best [depth]：分析目前最佳下法")
            print("state：顯示輪到誰與局面狀態")
            continue
        if cmd == "state":
            print(f"目前輪到：{analyzer.board.side_to_move.value}")
            print(f"局面：{analyzer.board.state()}")
            continue
        if cmd == "best":
            depth = int(parts[1]) if len(parts) >= 2 and parts[1].isdigit() else 3
            a = analyzer.suggest(depth)
            print(f"最佳下法：{a.best_move.uci if a.best_move else '(none)'}")
            print(f"評估分數：{a.evaluation}")
            if a.pv:
                print("主變化：" + " ".join(m.uci for m in a.pv))
            continue
        if cmd == "move":
            if len(parts) < 2:
                print("請輸入 move e2e4")
                continue
            depth = int(parts[2]) if len(parts) >= 3 and parts[2].isdigit() else 3
            try:
                m, ev, suggestion = analyzer.record(parts[1], depth)
                print(f"已套用走法：{m.uci}")
                print(f"下一手建議：{suggestion.uci if suggestion else '(none)'}")
                print(f"局面評估：{ev}")
                print(f"目前輪到：{analyzer.board.side_to_move.value}")
                print(f"局面：{analyzer.board.state()}")
            except ValueError as e:
                print(f"走法錯誤：{e}")
            continue

        print("未知指令，輸入 help 查看說明")


if __name__ == "__main__":
    run_cli()
