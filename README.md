# Plugin Compatibility Check

Plugin Compatibility Check は、Redmine のバージョンアップ前にインストール済みプラグインの互換性と危険度を静的に診断する Redmine プラグインです。

この MVP は読み取り専用です。Redmine のアップグレード、プラグインファイルの変更、migration 実行、gem install などの破壊的・変更系操作は行いません。

## 対象

- Redmine 3.3.0 以上
- 実運用確認の主対象: Redmine 3.3.3
- 対応想定範囲:
  - Redmine 3.3.x / 3.4.x
  - Redmine 4.0.x / 4.1.x / 4.2.x
  - Redmine 5.0.x / 5.1.x
  - Redmine 6.0.x / 6.1.x
- 対象 Redmine がサポートする Ruby / Rails
- 管理者のみ閲覧可能
- 外部 gem 追加なし

Redmine 3.3 系でも読み込めるよう、plugin 本体は古い Ruby で問題になりやすい `keyword_init`、`Regexp#match?`、`String#delete_prefix`、safe navigation などに依存しない実装にしています。

## 機能

- 現在の Redmine / Ruby / Rails バージョン表示
- installed plugins 一覧表示
- 各 plugin の基本情報解析
  - plugin id
  - name
  - version
  - author
  - plugin directory 内の最終更新日
  - `requires_redmine`
  - `init.rb` 内の Redmine バージョン条件らしき記述
  - `db/migrate` の有無
  - `Gemfile` の有無
- 任意で plugin の最新バージョン取得
  - `plugin.url` または plugin directory の `.git/config` から GitHub repository を検出
  - GitHub Releases の latest を取得
  - Release がない場合は Tags を fallback として取得
- target Redmine version と `requires_redmine` の簡易比較
- `requires_redmine` が下限のみかどうかの判定
- 現在の Redmine major version から target major version へのジャンプ判定
- plugin source の簡易互換性 scan
  - `alias_method_chain`
  - `Dispatcher.to_prepare`
  - `require_dependency 'dispatcher'`
  - `before_filter` / `after_filter`
  - `unloadable`
  - `attr_accessible`
  - `ActiveRecord::Observer`
  - `send(:include)` による monkey patch
- `OK` / `Warning` / `Unknown` / `Risky` の診断表示
- Risky / Warning / Unknown / OK の優先順表示
- ステータス絞り込み
  - すべて
  - 要確認のみ
  - Risky / Warning / Unknown / OK
- Risky/Unknown の理由列
- 詳細列の表示切り替え
- CSV export
  - 画面の絞り込みを反映
  - 棚卸し用の `review_result` / `action_plan` 空列を追加

## インストール

Redmine の `plugins` 配下にこのディレクトリを配置します。

```bash
cd /path/to/redmine
cp -r /path/to/redmine_plugin_check plugins/redmine_plugin_check
```

Redmine を再起動します。

Passenger、Puma、Unicorn、thin など、利用中のアプリケーションサーバーを再起動してください。

この MVP では database migration は不要です。

## 使い方

1. Redmine に管理者としてログインします。
2. **管理** 画面を開きます。
3. 管理メニューの **Plugin Check** を開きます。
4. `3.4.13`、`4.2.11`、`5.1.12`、`6.1.2` などの移行先 Redmine バージョンを入力します。
5. 診断テーブルを確認します。
6. 必要に応じて **表示** で `要確認のみ`、`Risky`、`Warning` などに絞り込みます。
7. 必要に応じて **最新バージョン情報も取得する** にチェックを入れて再表示します。
8. 詳しい根拠列を確認したい場合は **詳細列も表示する** にチェックを入れます。
9. 必要に応じて **CSV 出力** をクリックします。

最新バージョン取得は best effort です。すべての Redmine plugin が公式な配布元や release 情報を持つわけではないため、GitHub repository を検出できる plugin のみ対象になります。ネットワーク接続、private repository、認証が必要な repository、GitHub API rate limit、古い Ruby 環境の TLS 設定などによって `取得不可` / `取得失敗` / `認証が必要` / `rate limit` / `SSL エラー` などになる場合があります。

## 診断ルール

MVP のため、判定は意図的に単純で保守的です。

- `OK`: target version が `requires_redmine` を満たし、migration / Gemfile / 独自バージョン条件 / 旧 API pattern が見つからない。
- `Warning`: `db/migrate`、独自 `Gemfile`、`init.rb` 内の Redmine バージョン条件らしき記述、または旧 API pattern がある。
- `Unknown`: `requires_redmine` がなく、バージョン条件らしき記述も見つからない。
- `Risky`: target version が `requires_redmine` を満たさない、または target が Redmine 4+ で `alias_method_chain` など壊れる可能性が高い旧 pattern がある。

一覧では `Risky/Unknown の理由` に優先して確認したい理由を短く表示します。`OK` の場合は表示ノイズを減らすため原則 `-` になり、補足情報は `メモ` に残ります。

`互換性 scan` は検出した file path と行番号を表示します。コメント行や説明用の `:alias_method_chain_breaking` のような文字列は、できるだけ誤検出しないように除外しています。

`OK` は静的解析上の簡易判定です。実際の互換性を保証するものではありません。
特に `requires_redmine :version_or_higher => '3.3.0'` のような下限のみの指定は、最新 Redmine での互換性を保証しません。
ただし、Redmine 3.3 から 6.x への診断では多くの plugin が下限のみになりやすいため、下限のみ + major version jump だけでは `Warning` にせず、別列とメモで表示します。`Warning` / `Risky` は、より具体的なリスク材料がある plugin を目立たせるために使います。

## 主要ファイル

- `init.rb`: plugin 登録と管理メニュー追加。
- `config/routes.rb`: `plugin_check` route 定義。
- `app/controllers/redmine_plugin_check_controller.rb`: 管理者画面、絞り込み、優先ソート、CSV export。
- `app/services/redmine_plugin_check/analyzer.rb`: installed plugins の解析と診断結果生成。
- `app/services/redmine_plugin_check/compatibility_scanner.rb`: plugin source 内の古い Rails/Redmine pattern を検出。
- `app/services/redmine_plugin_check/latest_version_checker.rb`: GitHub Releases/Tags から最新バージョンを best effort で取得。
- `app/services/redmine_plugin_check/version_requirement.rb`: `requires_redmine` と target version の簡易比較。
- `app/views/redmine_plugin_check/index.html.erb`: summary、target version form、診断テーブル、CSV link。
- `assets/stylesheets/redmine_plugin_check.css`: Redmine 管理画面向けの軽いスタイル。
- `config/locales/en.yml` / `config/locales/ja.yml`: 英語・日本語ラベル。
- `test/unit/redmine_plugin_check/*_test.rb`: service class のテスト。

## 手元で動かす手順

Redmine checkout にこの plugin を配置した状態で確認します。

Redmine 3.3.x / 3.4.x / 4.x:

```bash
bundle exec rake redmine:plugins
bundle exec rake test TEST=plugins/redmine_plugin_check/test/unit/redmine_plugin_check/version_requirement_test.rb
bundle exec rake test TEST=plugins/redmine_plugin_check/test/unit/redmine_plugin_check/analyzer_test.rb
bundle exec rake test TEST=plugins/redmine_plugin_check/test/unit/redmine_plugin_check/latest_version_checker_test.rb
```

Redmine 5.x / 6.x:

```bash
bundle exec rails redmine:plugins
bundle exec rails test plugins/redmine_plugin_check/test/unit/redmine_plugin_check/version_requirement_test.rb
bundle exec rails test plugins/redmine_plugin_check/test/unit/redmine_plugin_check/analyzer_test.rb
bundle exec rails test plugins/redmine_plugin_check/test/unit/redmine_plugin_check/latest_version_checker_test.rb
```

画面確認:

```bash
bundle exec rails server
```

ブラウザで Redmine に管理者ログインし、**管理 > Plugin Check** を開きます。

## 互換性確認の推奨マトリクス

全 patch version を毎回起動確認するのは重いため、まずは各系列の代表として以下を確認するのがおすすめです。

- Redmine 3.3.3
- Redmine 3.4 latest
- Redmine 4.2 latest
- Redmine 5.1 latest
- Redmine 6.1 latest

Redmine 3.3.x 全 patch を厳密に保証したい場合は、3.3.0 と 3.3.9 など、系列の最初と最後に近い patch でも同じ確認を行ってください。

## 今後の拡張案

- plugin の repository URL 検出対象を GitLab、Bitbucket、Redmine.org plugin directory まで広げる。
- Redmine major version ごとの既知の破壊的変更をルール化する。
- plugin source を scan して削除済み Redmine API 利用を検出する。
- CI や事前点検向けに JSON export を追加する。
- 組織内の allowlist / 手動確認メモ / 判定 override を保存できるようにする。
- 診断履歴を保存し、前回との差分を表示する。
