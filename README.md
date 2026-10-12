# delphinus/homebrew-macskk

[macSKK](https://github.com/mtgto/macSKK) を**本家に入っていないパッチ (確定アンドゥほか) を当てた状態**で配る Homebrew tap。

```sh
brew tap delphinus/macskk
brew install delphinus/macskk/macskk-kakutei-undo
```

**公式の cask (`brew install --cask macskk`) とは排他。**先に片付けること (下記)。

## 何を足しているか

パッチは [`patches/`](patches) に 1 つの PR につき 1 枚ずつ置いてある。それぞれ [delphinus/macSKK](https://github.com/delphinus/macSKK) の同名のブランチから作り、upstream に PR として出している。

| パッチ | ブランチ | upstream の PR |
|---|---|---|
| [`kakutei-undo.patch`](patches/kakutei-undo.patch) | `kakutei-undo` | [mtgto/macSKK#524](https://github.com/mtgto/macSKK/pull/524) |
| [`input-mode-panel-spaces.patch`](patches/input-mode-panel-spaces.patch) | `fix-input-mode-panel-spaces` | [mtgto/macSKK#529](https://github.com/mtgto/macSKK/pull/529) |

**PR が取り込まれたリリースが出たら、そのパッチを消す。**全部消えたらこの tap は畳む。

### 確定アンドゥ (`kakutei-undo.patch`)

**⌃⇧R で直前の確定を取り消して変換候補選択に戻る** (ddskk の `skk-undo-kakutei` 相当)。確定したときの変換候補が選択された状態で戻るので、そこからスペースで次の変換候補、前候補キーを続ければ読み (▽) まで戻れる。確定した文字列がクライアントに残っていれば、**後ろに続きを入力していても取り消せる**。補完候補 (ピリオドキー・一定時間後の選択用のキー) や変換候補パネルのダブルクリックから確定した文字列も取り消せる。

`setMarkedText` の `replacementRange` で確定済み文字列を未確定文字列に置き換えている。**macOS 26.0 では無視されていたが 26.6 では届く**ようになった。アプリごとの結果は次のとおり。

| 結果 | アプリ |
|---|---|
| ▼ に戻る | テキストエディット, Safari, Chrome, Slack, Obsidian |
| 確定した直後だけ ▼ に戻る | Terminal.app (キャレットの直前で終わる範囲しか置き換えない) |
| 何もしない | iTerm2 (範囲指定を使わないので無効にしている), WezTerm, Ghostty (文書の中身を見せない) |

キーバインドのアクション名は `kakuteiUndo`、既定は ⌃⇧R (macOS 標準の日本語入力の再変換と同じ)。

### 入力モードパネルをどの操作スペースでも出す (`input-mode-panel-spaces.patch`)

本家の入力モードパネルは、最初に表示された操作スペースに残り続ける。そのため、操作スペースを複数使っていると別の操作スペースでは表示されず、フルスクリーンのアプリの上でも出たり出なかったりする。パネルの `collectionBehavior` に `.canJoinAllSpaces` と `.fullScreenAuxiliary` を設定して、どこでも表示されるようにしている。

## 仕組み

- 公式 cask は `pkg` で `/Library/Input Methods/` に入れるので **sudo が要る**。この tap は cask の `input_method` スタンザで `~/Library/Input Methods/` に置くので、**インストールも更新も sudo なしで通る**。daily-sync のような無人のジョブから `brew upgrade` するだけで追随できる。
- upstream の release tarball ではなく、**GitHub Actions で upstream のタグにパッチを当ててビルドしたものを自前の release に置いて配る**。各端末でのビルドは要らない。
- 上流に新しいリリースが出ると [`upstream.yml`](.github/workflows/upstream.yml) が日次で検知して PR を作る。その PR の CI が `patches/*.patch` を名前順にすべて当ててビルドするので、**パッチが当たらなくなったらそこで落ちて気付ける**。
- main に入ると [`build.yml`](.github/workflows/build.yml) が `xcode-27` のランナー (Xcode 27.0、upstream の CI と同じ) でビルドして release に上げ、cask に sha256 を書き戻す。
- バージョンは `<upstream のリリース>,<パッチの版>`。パッチだけ直したいときは後ろを上げる。アプリの `MARKETING_VERSION` は upstream の番号のままにしてあるので、macSKK 自身の更新通知は静かなまま。

## パッチを直したとき

[delphinus/macSKK](https://github.com/delphinus/macSKK) のパッチのブランチ (上の表) を直したら、この tap にも持ってくる。以下は `kakutei-undo` の例。新しいパッチを足すときも同じ手順で `patches/` に置けばよく、ワークフローは触らなくてよい。

各ブランチは PR のブランチなので、リリースのタグではなく **upstream の main の上にあり、main をマージしながら進む**。タグとの差分を素朴に取ると、ブランチに入っているタグ以降の上流の変更までパッチに入ってしまうことがある。そこで **upstream の main との分岐点からの差分 (`origin/main...kakutei-undo`、PR の差分と同じもの) を取り、全部のパッチが CI と同じ名前順でタグに当たることを確かめる**。

```sh
cd <macSKK のチェックアウト>
git fetch origin --tags
git diff origin/main...kakutei-undo > <この tap>/patches/kakutei-undo.patch
git worktree add --detach /tmp/macskk-apply <cask のタグ>   # 例: 2.21.1
for p in <この tap>/patches/*.patch; do git -C /tmp/macskk-apply apply --3way "$p" || break; done
git worktree remove --force /tmp/macskk-apply
```

そのうえで `Casks/macskk-kakutei-undo.rb` の `version` の**カンマの後ろを 1 つ上げる** (`"2.21.0,1"` → `"2.21.0,2"`)。upstream のリリースは変わっていないので前半は据え置き。

main に push すると `build.yml` がビルドして release を作り、sha256 を書き戻す。`sha256` は触らなくてよい (どうせ上書きされる)。**ビルドのたびに zip のハッシュは変わる**ので、`Casks/**` や `patches/**` を触るときは版も一緒に上げること。上げずに push すると、既存の release を新しい zip で上書きしてから sha256 を書き戻すまでのあいだ、`brew install` がハッシュ不一致で落ちる。

## upstream に新しいリリースが出たとき

`upstream.yml` が作る PR は版の前半を上げ、後半を 1 に戻す (`"2.21.0,3"` → `"2.21.1,1"`)。パッチは古いままなので、**その PR のブランチで上の「パッチを直したとき」と同じ手順でパッチを取り直す**。そのリリースに取り込まれた PR のパッチは、取り直さずに消す。`kakutei-undo` が新しいタグより古い main の上にあるなら、先に upstream の main を `kakutei-undo` にマージする。

```sh
cd <macSKK のチェックアウト>
git fetch origin --tags
git switch kakutei-undo
git merge origin/main
git push fork kakutei-undo
```

**rebase しない。** `kakutei-undo` は upstream への PR のブランチも兼ねていて、レビュアーもこのブランチに push する。rebase して force push すると、その push を消してしまうし、PR のコメントに書いたコミットのハッシュも変わる。

取り直したパッチを tap の PR のブランチに push すれば CI がやり直される。新しいタグに当たらなければ、そのタグの上で衝突を解いたパッチを別に作る。

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
- **Terminal.app では選べない。** Terminal.app は `~/Library/Input Methods/` に置いた入力メソッドを入力メニューでグレーにする。Terminal.app で使うには `/Library/Input Methods/` に置く必要があり、その場合はこの tap は使えない (置き換えたあとは macOS の再起動も要った)。
- 辞書・skkserv の設定・コンテナは bundle identifier が同じなので公式版と共通。置き場所を変えても引き継がれる。
