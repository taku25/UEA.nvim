# UEA.nvim

# Unreal Engine Asset Inspector 💓 Neovim

`UEA.nvim`は、Unreal Engineのアセットを調査し、それらの関連性を発見するために設計されたNeovimプラグインです。C++クラスの`.uasset`（Blueprint）での使用箇所を検索することで、C++コードとBlueprintアセット間のギャップを埋めます。

これは **Unreal Neovim Plugin sweet** のユーティリティプラグインです。ライブラリとして [UNL.nvim](https://github.com/taku25/UNL.nvim) に依存し、[UEP.nvim](https://github.com/taku25/UEP.nvim) からデータを取得します。

[English](README.md) | [日本語 (Japanese)](README_ja.md)

-----

## ✨ 機能 (Features)

  * **Blueprint 使用箇所の検索**:
      * `:UEA find_bp_usages` コマンドを提供し、特定のC++クラスから継承しているすべてのBlueprintアセット（`.uasset`, `.umap`）を検索します。
  * **高速なバイナリGrep**:
      * [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) を使用し、バイナリアセットファイルに対して非常に高速で非侵入的な検索を直接実行します。
  * **エコシステム連携**:
      * `UEP.nvim` の `uep.get_project_classes` プロバイダーを利用し、プロジェクト内の全C++クラスの検索可能なリストを表示します。
      * アセット内の `NativeParentClass` 名を正しく見つけるために、C++のプレフィックス（`A`, `U`, `F`など）を自動的に除去します。
  * **UI統合**:
      * `UNL.nvim`のUI抽象化レイヤーを活用し、[Telescope](https://github.com/nvim-telescope/telescope.nvim)や[fzf-lua](https://github.com/ibhagwan/fzf-lua)のようなUIフロントエンドを自動的に使用します。
      * デフォルトの[Enter]アクションは、選択されたアセットのゲームパス（例: `/Game/Blueprints/BP_MyActor`）をクリップボードにコピーし、Unreal Editorのコンテンツブラウザにペーストできるようにします。

## 🔧 必要要件 (Requirements)

  * Neovim v0.11.3 以上
  * [**UNL.nvim**](https://github.com/taku25/UNL.nvim) (**必須**)
  * [**UEP.nvim**](https://github.com/taku25/UEP.nvim) (**必須** C++クラスのプロバイダーとして)
  * [rg](https://github.com/BurntSushi/ripgrep) (**アセット検索に必須**)
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
     'taku25/UEP.nvim',
     'nvim-telescope/telescope.nvim', -- オプション
  },
  opts = {
    -- UEA固有の設定があればここに記述します
  },
}
```

## ⚙️ 設定 (Configuration)

このプラグインは、ライブラリである`UNL.nvim`のセットアップ関数を通じて設定されます。ただし、`UEA.nvim`に直接`opts`を渡すことで、`UEA`名前空間の設定を行うことも可能です。

以下は`UEA.nvim`に関連するデフォルト値です。

```lua
-- lazy.nvimのUEA.nvimまたはUNL.nvimのspec内に記述
opts = {
  -- UEA固有の設定
  uea = {
    -- 将来的なUEA固有設定のためのセクション
  },
  
  -- アセットgrep ('rg') の設定
  asset_grep = {
    -- 実行するコマンド
    base_command = "rg",
    
    -- 検索パターンのテンプレート。 %s はC++のベースクラス名(プレフィックス除外後)に置換されます
    search_pattern_template = "NativeParentClass.*'%s'",
    
    -- 検索対象とするアセットのglobパターン
    glob_patterns = {
      "BP_*.uasset",
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
```

### コマンド詳細

  * **`:UEA find_bp_usages[!] [ClassName]`**:
      * 指定されたC++クラスから継承しているすべてのBlueprintアセット（`.uasset`, `.umap`）を検索します。
      * `!`なし: `[ClassName]`引数が指定されていればそれを使用し、なければカーソル下の単語を使用します。
      * `!`あり: 引数やカーソル下の単語を無視し、常にプロジェクト全体のC++クラス（`UEP.nvim`から提供）を選択するためのピッカーUIを開きます。
      * **アクション**: 結果ピッカーで選択肢に対して`<Enter>`を押すと、アセットのゲームパス（例: `/Game/Blueprints/BP_MyActor`）がクリップボードにコピーされます。

## 🤖 API & 自動化 (Automation Examples)

`UEA.api`モジュールを使用して、他のNeovim設定と連携させることができます。

### キーマップ作成例

カーソル下のクラスの使用箇所を素早く検索するためのキーマップを作成します。

```lua
-- init.lua や keymaps.lua などに記述
-- カーソル下のクラスの使用箇所を検索
vim.keymap.set('n', '<leader>au', function()
  require('UEA.api').find_bp_usages({ has_bang = false })
end, { noremap = true, silent = true, desc = "UEA: アセット使用箇所の検索 (カーソル)" })

-- C++クラスのリストから選択して検索
vim.keymap.set('n', '<leader>aU', function()
  require('UEA.api').find_bp_usages({ has_bang = true })
end, { noremap = true, silent = true, desc = "UEA: アセット使用箇所の検索 (ピッカー)" })
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
