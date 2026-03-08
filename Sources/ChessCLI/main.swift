import Foundation
import ChatGPTKit

func printHelp() {
    print("""
    ChessCLI 指令：
      move <uci> [depth]   輸入一步棋並分析（例如: move e2e4 3）
      best [depth]         分析目前局面最佳下法（例如: best 4）
      state                顯示目前對局狀態
      help                 顯示指令說明
      quit                 離開
    """)
}

func printState(_ state: ChessGameState) {
    switch state {
    case .inProgress:
        print("對局狀態：進行中")
    case .stalemate:
        print("對局狀態：和局（stalemate）")
    case .checkmate(let winner):
        print("對局狀態：將死，\(winner.rawValue) 勝")
    }
}

let analyzer = ChessGameAnalyzer()

print("歡迎使用 ChessCLI！")
print("你可以跟朋友下棋時，輸入每一步 UCI 走法（例如 e2e4）。")
printHelp()

while true {
    print("\n> ", terminator: "")
    guard let raw = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        continue
    }

    let parts = raw.split(separator: " ").map(String.init)
    let command = parts[0].lowercased()

    switch command {
    case "quit", "exit":
        print("再見！")
        exit(0)

    case "help":
        printHelp()

    case "state":
        print("目前輪到：\(analyzer.board.sideToMove.rawValue)")
        printState(analyzer.board.gameState())

    case "best":
        let depth = parts.count >= 2 ? (Int(parts[1]) ?? 3) : 3
        let analysis = analyzer.suggestBestMove(depth: depth)
        print("建議深度：\(depth)")
        print("最佳下法：\(analysis.bestMove?.uci ?? "(none)")")
        print("評估分數：\(analysis.evaluation)")
        if !analysis.principalVariation.isEmpty {
            let pv = analysis.principalVariation.map { $0.uci }.joined(separator: " ")
            print("主變化：\(pv)")
        }

    case "move":
        guard parts.count >= 2 else {
            print("請輸入走法，例如：move e2e4")
            continue
        }

        let move = parts[1]
        let depth = parts.count >= 3 ? (Int(parts[2]) ?? 3) : 3

        do {
            let review = try analyzer.recordMove(move, depth: depth)
            print("已套用走法：\(review.playedMove.uci)")
            print("下一手建議：\(review.suggestedReply?.uci ?? "(none)")")
            print("局面評估：\(review.evaluationAfterMove)")
            print("目前輪到：\(analyzer.board.sideToMove.rawValue)")
            printState(analyzer.board.gameState())
        } catch {
            print("走法錯誤：\(error)")
        }

    default:
        print("未知指令：\(command)")
        printHelp()
    }
}
