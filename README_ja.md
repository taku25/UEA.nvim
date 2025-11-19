# UEA.nvim

# Unreal Engine Asset Inspector 💓 Neovim

`UEA.nvim`は、Unreal Engineのアセットを調査し、それらの関連性を発見するために設計されたNeovimプラグインです。C++クラスの`.uasset`（Blueprint）での使用箇所を検索したり、アセット間の参照関係をスキャンすることで、C++コードとBlueprintアセット間のギャップを埋めます。

これは **Unreal Neovim Plugin sweet** のユーティリティプラグインです。ライブラリとして [UNL.nvim](https://github.com/taku25/UNL.nvim) に依存し、[UEP.nvim](https://github.com/taku25/UEP.nvim) からデータを取得します。

[English](README.md) | [日本語 (Japanese)](README_ja.md)

-----

## ✨ 機能 (Features)

  * **Blueprint 使用箇所の検索**:
      * `:UEA find_bp_usages` コマンドを提供し、特定のC++クラスから継承しているすべてのBlueprintアセット（`.uasset`, `.umap`）を検索します。
  * **アセット参照検索**:
      * `:UEA find_references` コマンドを提供し、特定のアセットを参照している他のアセットを検索します (Reference ViewerのReferencers機能相当)。
  * **アセット依存関係検索**:
      * `:UEA find_dependencies` コマンドを提供し、バイナリアセットの内部的な依存関係を検索します (Reference ViewerのDependencies機能相当)。
  * **バイナリ文字列Grep**:
      * `:UEA grep_string` コマンドを提供し、バイナリアセット内の任意の文字列（GameplayTag、ソケット名など）を検索します。
  * **エディタ連携**:
      * `:UEA show_in_editor` コマンドを提供し、Web Remote Control経由でUnreal Editorのコンテンツブラウザを選択したアセットに同期させます。
  * **システム連携**:
      * `:UEA system_open` コマンドを提供し、OSのファイルエクスプローラーでアセットの場所を開きます。
  * **Code Lens**:
      * C++クラス定義の横に、Blueprintでの使用数（参照数）を仮想テキストとして表示します。
  * **高速なバイナリスキャン**:
      * [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) と [fd](https://github.com/sharkdp/fd) を使用し、バイナリアセットファイルに対して非常に高速で非侵入的な検索を実行します。
  * **エコシステム連携**:
      * `UEP.nvim` からC++クラスデータを取得します。
      * C++のプレフィックス（`A`, `U`など）を自動除去してマッチングします。
      * UE5のOFPA (One File Per Actor) フォルダなどをインテリジェントに除外します。

## 🔧 必要要件 (Requirements)

  * Neovim v0.11.3 以上
  * [**UNL.nvim**](https://github.com/taku25/UNL.nvim) (**必須**)
  * [**UEP.nvim**](https://github.com/taku25/UEP.nvim) (**必須** C++クラスのプロバイダーとして)
  * [rg](https://github.com/BurntSushi/ripgrep) (**アセット検索に必須**)
  * [fd](https://github.com/sharkdp/fd) (**アセットリスト取得に必須**)
  * **オプション (完全な体験のために、導入を強く推奨):**
      * **UI (Picker):**
          * [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
          * [fzf-lua](https://github.com/ibhagwan/fzf-lua)

## 🚀 インストール (Installation)

お好みのプラグインマネージャーでインストールしてください。

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  'taku25/UEA.nvim',
  -- UNL.nvim と UEP.nvim は必須の依存関係です
  dependencies = {
    { 'taku25/UNL.nvim', lazy=false, },
     'nvim-telescope/telescope.nvim', -- オプション
  },
  opts = {
    -- UEA固有の設定があればここに記述します
  },
}
````

## ⚙️ 設定 (Configuration)

このプラグインは、ライブラリである`UNL.nvim`のセットアップ関数を通じて設定されます。ただし、`UEA.nvim`に直接`opts`を渡すことで、`UEA`名前空間の設定を行うことも可能です。

以下は`UEA.nvim`に関連するデフォルト値です。

```lua
-- lazy.nvimのUEA.nvimまたはUNL.nvimのspec内に記述
opts = {
  -- Code Lens (仮想テキスト) の設定
  code_lens = {
    enable = true, -- 自動Code Lensを有効/無効化
  },
  
  -- アセットgrep ('rg') の設定
  asset_grep = {
    -- 実行するコマンド
    base_command = "rg",
    
    -- 検索パターンのテンプレート。 %s はC++のベースクラス名(プレフィックス除外後)に置換されます
    search_pattern_template = "NativeParentClass.*%s",
    
    -- 検索対象とするアセットのglobパターン
    glob_patterns = {
      "*.uasset",
      "*.umap",
    }
  },

  -- UIバックエンドの設定 (UNL.nvimから継承)
  ui = {
    picker = {
      mode = "auto", -- "auto", "telescope", "fzf_lua", "native"
      prefer = { "telescope", "fzf_lua", "native" },
    },
  },
}
```

## ⚡ 使い方 (Usage)

すべてのコマンドは`:UEA`から始まります。

```viml
" C++クラスのBlueprint使用箇所を検索します
:UEA find_bp_usages[!] [ClassName]

" アセットの被参照（参照されている場所）を検索します
:UEA find_references[!] [AssetPath]

" アセットの依存関係（参照しているもの）を検索します
:UEA find_dependencies[!] [AssetPath]

" バイナリアセットの親クラス情報を表示します
:UEA find_bp_parent[!] [AssetPath]

" バイナリアセット内の文字列をGrepします
:UEA grep_string[!] [Query]

" Unreal Editorのコンテンツブラウザを同期します
:UEA show_in_editor[!] [AssetPath]

" OSのファイルエクスプローラーでアセットの場所を開きます
:UEA system_open[!] [AssetPath]

" アセットのUnrealオブジェクトパスをクリップボードにコピーします
:UEA copy_reference[!]

" Code Lens（Blueprint参照数表示）を手動で更新します
:UEA refresh_lens
```

### コマンド詳細

  * **`:UEA find_bp_usages[!] [ClassName]`**:
      * 指定されたC++クラスから継承しているすべてのBlueprintアセットを検索します。
      * `!` (Bang): 引数やカーソル下の単語を無視し、プロジェクト全体のC++クラスを選択するためのピッカーUIを開きます (UEP.nvimが必要)。
      * `[ClassName]`: 省略した場合、カーソル下の単語 (`<cword>`) が使用されます。
  * **`:UEA find_references[!] [AssetPath]`**:
      * 指定されたアセットを参照している他のアセットを検索します。
      * `!` (Bang): Contentディレクトリ内の全アセットから選択するピッカーUIを開きます。
      * `[AssetPath]`: 省略した場合、クリップボード内のアセットパス（例: `/Game/BP_Hero`）を確認します。空の場合は入力を促します。
  * **`:UEA find_dependencies[!] [AssetPath]`**:
      * 指定されたアセットが依存している（内部で参照している）アセットを検索します。
      * 使い方は `:UEA find_references` と同様です。
  * **`:UEA grep_string[!] [Query]`**:
      * Contentディレクトリ内のバイナリアセット (`.uasset`, `.umap`) に対して任意の文字列をGrep検索します。GameplayTagやソケット名を探すのに便利です。
      * `!` (Bang): 検索クエリの入力を促します。
      * `[Query]`: 省略した場合、カーソル下の単語を使用します。
  * **`:UEA find_bp_parent[!] [AssetPath]`**:
      * バイナリアセットファイルから親クラス情報 (`NativeParentClass`) を抽出し、表示します。
      * 使い方は `:UEA find_references` と同様です。
  * **`:UEA show_in_editor[!] [AssetPath]`**:
      * 実行中のUnreal Editorに対して（Web Remote Control経由で）コマンドを送信し、コンテンツブラウザを指定されたアセットに同期（フォーカス）させます。
      * UE側で "Remote Control API" プラグインが有効である必要があります。
      * 使い方は `:UEA find_references` と同様です。
  * **`:UEA system_open[!] [AssetPath]`**:
      * OSのファイルエクスプローラー（Explorer/Finder）で、アセットファイルが選択された状態でフォルダを開きます。
      * 使い方は `:UEA find_references` と同様です。
  * **`:UEA copy_reference[!]`**:
      * ピッカーを開いてアセットを選択し、そのUnrealオブジェクトパス（例: `/Game/BP.BP_C`）をクリップボードにコピーします。
  * **`:UEA refresh_lens`**:
      * Code Lens（クラス定義の横に表示されるBP参照数）を手動で更新します。
      * Code Lens はファイルの読み込み・保存時に自動更新されますが、このコマンドで強制的に再スキャンできます。

## 🤖 API & 自動化 (Automation Examples)

`UEA.api`モジュールを使用して、他のNeovim設定と連携させることができます。

```lua
local uea_api = require("UEA.api")

-- カーソル下のクラスの使用箇所を検索
vim.keymap.set('n', '<leader>au', function()
  uea_api.find_bp_usages({ has_bang = false })
end, { noremap = true, silent = true, desc = "UEA: アセット使用箇所の検索 (カーソル)" })

-- クリップボードのアセットパスの参照を検索
vim.keymap.set('n', '<leader>ar', function()
  uea_api.find_references({ has_bang = false })
end, { noremap = true, silent = true, desc = "UEA: 参照検索 (クリップボード)" })
```

## その他

**Unreal Engine 関連プラグイン:**

  * **[UEP.nvim](https://github.com/taku25/UEP.nvim)**
      * `uproject`を解析してファイルナビゲートなどを簡単に行えるようになります
  * **[UEA.nvim](https://www.google.com/search?q=https://github.com/taku25/UEA.nvim)** (このプラグイン)
      * C++クラスがどのBlueprintアセットから使用されているかを検索します
  * **[UBT.nvim](https://github.com/taku25/UBT.nvim)**
      * BuildやGenerateClangDataBaseなどを非同期でNeovim上から使えるようになります
  * **[UCM.nvim](https://github.com/taku25/UCM.nvim)**
      * クラスの追加や削除がNeovim上からできるようになります。
  * **[ULG.nvim](https://github.com/taku25/ULG.nvim)**
      * UEのログやliveCoding,stat fpsなどnvim上からできるようになります
  * **[USH.nvim](https://github.com/taku25/USH.nvim)**
      * ushellをnvimから対話的に操作できるようになります
  * **[neo-tree-unl](https://github.com/taku25/neo-tree-unl.nvim)**
      * IDEのようなプロジェクトエクスプローラーを表示できます。
  * **[tree-sitter for Unreal Engine](https://github.com/taku25/tree-sitter-unreal-cpp)**
      * UCLASSなどを含めてtree-sitterの構文木を使ってハイライトができます。

## 📜 ライセンス (License)

MIT License

Copyright (c) 2025 taku25

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

