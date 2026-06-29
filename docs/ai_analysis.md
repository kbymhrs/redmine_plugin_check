# AI Analysis Feature Specification

## 目的

Plugin Compatibility Check の診断結果を、管理者が次に取るべき行動へ変換しやすくする。

既存の CSV 出力は棚卸しと表計算向けに残し、AI 分析向けには Markdown 形式の構造化レポートを追加する。さらに、任意で AI API にその Markdown を送信し、画面上で分析結果を確認できるようにする。

## 対象ユーザー

- Redmine の管理者
- Redmine のアップグレード計画を立てる担当者
- プラグインの更新、削除、代替検討、動作確認の優先順位を整理したい担当者

## 方針

- 既存の診断は読み取り専用のまま維持する。
- AI API 連携は任意機能とし、API 設定がない環境でも Markdown 出力だけで利用できるようにする。
- API キーは環境変数を優先し、画面設定に保存された値は補助的に扱う。
- AI に送る情報は診断結果に限定し、秘密情報らしい値は Markdown 生成時にマスクする。
- AI の回答は参考情報として表示し、自動で Redmine やプラグインを変更しない。

## 機能 1: AI 用 Markdown 出力

### UI

診断画面に以下の導線を追加する。

- AI 用 Markdown 出力

既存の絞り込み条件を反映する。

- 移行先 Redmine バージョン
- 最新バージョン取得の有無
- ステータス絞り込み
- 詳細列表示の有無

### 出力形式

Markdown には以下を含める。

1. レポート概要
   - 現在の Redmine バージョン
   - Ruby バージョン
   - Rails バージョン
   - 移行先 Redmine バージョン
   - 出力日時
   - 対象プラグイン数
   - ステータス別件数

2. 優先確認リスト
   - Risky / Warning / Unknown の順に、対応優先度が高いプラグインを列挙する。
   - 各プラグインの主な理由を短く記載する。

3. プラグイン別詳細
   - status
   - name
   - plugin id
   - version
   - latest version
   - latest version source
   - latest version error
   - author
   - last modified at
   - requires_redmine
   - requires_redmine satisfied
   - requires_redmine lower bound only
   - target major jump
   - Redmine version condition in init.rb
   - db/migrate
   - Gemfile
   - compatibility findings
   - primary reasons
   - notes

4. AI への依頼文
   - 全体リスク
   - 優先対応プラグイン
   - プラグインごとの推奨対応
   - 削除、更新、代替検討が必要なもの
   - 追加調査が必要なもの
   - 実施順序
   - 管理者向けの簡潔な結論

### 秘密情報のマスク

Markdown 生成時に、以下のような値を `[REDACTED]` に置換する。

- `api_key=...`
- `token=...`
- `secret=...`
- `password=...`
- `Authorization: Bearer ...`
- `sk-...` 形式の API key らしき文字列

現時点では診断対象が主に plugin metadata と file path であるため過剰なマスクは避けるが、AI 送信前の安全策として最低限のマスクを行う。

## 機能 2: AI API 設定

Redmine plugin settings として以下を管理できるようにする。

- AI 分析を有効にする
- API provider label
- API endpoint
- API key
- API key environment variable
- Model
- Timeout seconds
- Max prompt characters
- System prompt

### 初期値

- AI 分析: 無効
- API provider label: OpenAI compatible
- API endpoint: `https://api.openai.com/v1/chat/completions`
- API key environment variable: `REDMINE_PLUGIN_CHECK_AI_API_KEY`
- Model: `gpt-4.1-mini`
- Timeout seconds: `60`
- Max prompt characters: `30000`

### API key の扱い

API key は以下の優先順位で取得する。

1. 設定された環境変数名から取得した値
2. plugin settings に保存された API key

画面設定に API key を保存できるようにするが、README では環境変数の利用を推奨する。

## 機能 3: AI で分析

### UI

診断画面に以下を追加する。

- AI で分析する

AI 分析が無効、または API key が取得できない場合は、ボタンを表示せず設定不足の説明を表示する。

### 送信内容

AI 用 Markdown と system prompt を送信する。

Markdown が max prompt characters を超える場合は、先頭から指定文字数までに切り詰め、切り詰めたことを Markdown 内に明記する。

### API

OpenAI compatible な chat completions API を対象にする。

Request:

```json
{
  "model": "gpt-4.1-mini",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ]
}
```

Response:

- `choices[0].message.content` を分析結果として表示する。

### エラー表示

以下の状態をユーザーに表示する。

- AI 分析が無効
- API endpoint 未設定
- API key 未設定
- HTTP error
- timeout
- JSON parse error
- API response format error
- その他の request error

## セキュリティと制限

- この機能は AI の回答を表示するだけで、Redmine や plugin file を変更しない。
- AI に送信される情報は、画面上で確認できる診断結果に限定する。
- API key はログや Markdown に含めない。
- 外部 gem は追加しない。
- Redmine 3.3 系で動く Ruby 構文に寄せる。

## 実装方針

- Markdown 生成は controller から分離し、service class にする。
- AI API 呼び出しも service class にする。
- controller は既存の診断条件、絞り込み、出力形式を束ねるだけにする。
- CSV 出力の既存挙動は変えない。
- テストは Markdown 生成と AI client の service class を中心に追加する。

## 今回の実装範囲

- 仕様書の追加
- AI 用 Markdown 出力
- AI API 設定
- AI API 送信と回答表示
- README 更新
- service test 追加

## 今回は実装しないもの

- AI 分析結果の DB 保存
- 分析履歴
- 分析結果の差分表示
- provider ごとの専用 UI
- Streaming response
- JSON schema / structured output
- Redmine や plugin file の自動変更
