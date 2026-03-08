# ChatGPTKit
A very simple Swifty API to use ChatGPT from OpenAI. Please let me know if you find any errors.

## Installation
1. In your Xcode project, go to File -> Add Packages
2. Enter the package URL: `https://https://github.com/heysaik/ChatGPTKit`
3. Click on **Add Package** and let Xcode install the Swift Package

## Usage
```swift
let chattyGPT = ChatGPTKit(apiKey: "YOUR-API-KEY")
var history = [ChatGPTKit.Message(role: .user, content: "Hello Swift ChatGPT")]

switch try await chattyGPT.performCompletions(messages: history) {
case .success(let response):
    let firstResponse = response.choices[0]
    history.append(firstReponse.message)
    print(firstResponse.message.content)
case .failure(let error):
    print(error)
}
```

## Types
This can help you understand how to use the package better. This is an exact Swift copy of the response object from the OpenAI API.
### Model
```swift
enum Model {
    case turbo
    case turbo31
}
```

### Role
```swift
enum Role {
    case assistant
    case user
}
```

### Message
```swift
struct Message {
    var role: Role
    var content: String
}
```

### APIUsage
```swift
struct APIUsage {
    var prompt_tokens: Int
    var completion_tokens: Int
    var total_tokens: Int
}
```

### ResponseChoice
```swift
struct ResponseChoice {
    var index: Int
    var message: Message
    var finish_reason: String
}
```

### Response
```swift
struct Response {
    var id: String
    var object: String
    var created: Int
    var choices: [ResponseChoice]
    var usage: APIUsage
}
```

## Compatibility 
- iOS 13.0+
- macOS 13.0+
- watchOS 9.0+
- tvOS 16.0+


## 直接執行（命令列）
如果你只是想「直接跑程式」分析對局，請用這個：

1. 打開終端機進到專案資料夾
2. 執行：`swift run ChessCLI`
3. 在 CLI 輸入指令

範例：
```bash
swift run ChessCLI
> move e2e4 3
> move e7e5 3
> best 3
> state
> quit
```

可用指令：
- `move <uci> [depth]`：輸入一步棋並立即分析
- `best [depth]`：分析目前最佳下一步
- `state`：顯示目前對局狀態
- `help`：顯示說明
- `quit`：離開程式

## Chess 分析器（新功能）
你可以用內建的 `ChessGameAnalyzer` 來記錄每一步棋，並在每一步後拿到建議下法。

```swift
import ChatGPTKit

let analyzer = ChessGameAnalyzer()

// 輸入你和朋友每一步（UCI 格式）
try analyzer.recordMove("e2e4", depth: 3)
try analyzer.recordMove("e7e5", depth: 3)

// 取得目前局面的最佳建議
let analysis = analyzer.suggestBestMove(depth: 3)
print("Best move:", analysis.bestMove?.uci ?? "(none)")
print("Eval:", analysis.evaluation)
print("PV:", analysis.principalVariation.map(\.uci))
```

### 目前支援
- 合法走法驗證
- 對局狀態判斷（進行中、將死、和局）
- Minimax + Alpha-Beta 剪枝的最佳下法搜尋
- UCI 走法輸入（例如 `e2e4`、`e7e8q`）

### 備註
目前為輕量版引擎，尚未包含王車易位（castling）與吃過路兵（en passant）。
