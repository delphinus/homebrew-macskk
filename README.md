# delphinus/homebrew-macskk

[macSKK](https://github.com/mtgto/macSKK) を**本家に入っていない確定アンドゥのパッチを当てた状態**で配る Homebrew tap。

```sh
brew tap delphinus/macskk
brew install delphinus/macskk/macskk-kakutei-undo
```

**公式の cask (`brew install --cask macskk`) とは排他。**先に片付けること (下記)。

## 何を足しているか

**⌃Z で直前の確定を取り消して変換候補選択に戻る** (ddskk の `skk-undo-kakutei` 相当)。確定したときの変換候補が選択された状態で戻るので、そこからスペースで次の変換候補、前候補キーを続ければ読み (▽) まで戻れる。確定した文字列がクライアントに残っていれば、**後ろに続きを入力していても取り消せる**。

`setMarkedText` の `replacementRange` で確定済み文字列を未確定文字列に置き換えている。**macOS 26.0 では無視されていたが 26.6 では届く**ようになった。ただし届くのは AppKit と WebKit のアプリだけで、Chromium ベースのアプリ (Chrome, Slack, Obsidian) とターミナルでは無視される。そちらでは置けたかどうかを読み直して判定し、確定した文字列を次の変換候補で置き換えて変換候補パネルを出すほうに切り替える。

キーバインドのアクション名は `kakuteiUndo`、既定は ⌃Z。macOS の標準のキーバインドでも macSKK の他の機能でも使われていない。

パッチの実体は [`patches/kakutei-undo.patch`](patches/kakutei-undo.patch)。由来は [delphinus/macSKK](https://github.com/delphinus/macSKK) の `fix-candidate-panel` ブランチ。**upstream に提案して取り込まれたらこの tap は畳む。**

## 仕組み

- 公式 cask は `pkg` で `/Library/Input Methods/` に入れるので **sudo が要る**。この tap は cask の `input_method` スタンザで `~/Library/Input Methods/` に置くので、**インストールも更新も sudo なしで通る**。daily-sync のような無人のジョブから `brew upgrade` するだけで追随できる。
- upstream の release tarball ではなく、**GitHub Actions で upstream のタグにパッチを当ててビルドしたものを自前の release に置いて配る**。各端末でのビルドは要らない。
- 上流に新しいリリースが出ると [`upstream.yml`](.github/workflows/upstream.yml) が日次で検知して PR を作る。その PR の CI がパッチを当ててビルドするので、**パッチが当たらなくなったらそこで落ちて気付ける**。
- main に入ると [`build.yml`](.github/workflows/build.yml) が `macos-26` でビルドして release に上げ、cask に sha256 を書き戻す。
- バージョンは `<upstream のリリース>,<パッチの版>`。パッチだけ直したいときは後ろを上げる。アプリの `MARKETING_VERSION` は upstream の番号のままにしてあるので、macSKK 自身の更新通知は静かなまま。

## パッチを直したとき

[delphinus/macSKK](https://github.com/delphinus/macSKK) の `fix-candidate-panel` を直したら、この tap にも持ってくる。

```sh
cd <macSKK のチェックアウト>
git diff 2.20.0..fix-candidate-panel > <この tap>/patches/kakutei-undo.patch
```

そのうえで `Casks/macskk-kakutei-undo.rb` の `version` の**カンマの後ろを 1 つ上げる** (`"2.20.0,1"` → `"2.20.0,2"`)。upstream のリリースは変わっていないので前半は据え置き。

main に push すると `build.yml` がビルドして release を作り、sha256 を書き戻す。`sha256` は触らなくてよい (どうせ上書きされる)。**ビルドのたびに zip のハッシュは変わる**ので、`Casks/**` や `patches/**` を触るときは版も一緒に上げること。上げずに push すると、既存の release を新しい zip で上書きしてから sha256 を書き戻すまでのあいだ、`brew install` がハッシュ不一致で落ちる。

## 二重に入れない

macOS は入力メソッドを **bundle identifier で起動する**ので、`/Library/Input Methods` と `~/Library/Input Methods` の両方に macSKK があると**どちらが起動するか分からなくなる**。起動したほうが IMK のセッションを張れないと、キー入力が丸ごと握り潰されて「キーボードが反応しない」ように見える。

守りは 3 枚:

| | |
|---|---|
| `conflicts_with cask: "macskk"` | 公式 cask が入っていれば brew が拒む |
| `preflight_steps` | `/Library/Input Methods/macSKK.app` が実在すれば中断する。**手で置いたビルドは brew から見えない**ので、ファイルの有無で見る |
| README のこの節 | 片付け方 |

初回だけ sudo が要る:

```sh
brew uninstall --cask macskk                      # 公式 cask から入れていた場合
sudo rm -rf "/Library/Input Methods/macSKK.app"   # 手で置いたビルドも含めて撤去
brew install delphinus/macskk/macskk-kakutei-undo
```

そのあと **システム設定 → キーボード → 入力ソース** で macSKK を追加し直す。

登録がおかしくなったときの確認:

```sh
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREG" -dump | awk '/^path: /{p=$0} /^identifier: +net\.mtgto\.inputmethod\.macSKK/{print p}' | sort -u
```

`~/Library/Input Methods/macSKK.app` の 1 つだけになっていること。

## 制限

- **ad-hoc 署名。** Developer ID の証明書を持っていないため。cask は落としてきたものに quarantine を付けるので、`postflight_steps` で外している。
- **macOS / Apple Silicon 向けにしかビルドしていない。**
- 辞書・skkserv の設定・コンテナは bundle identifier が同じなので公式版と共通。置き場所を変えても引き継がれる。
