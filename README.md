# UEA.nvim

# Unreal Engine Asset Inspector 💓 Neovim

`UEA.nvim` is a Neovim plugin designed to inspect Unreal Engine assets and find their relationships. It bridges the gap between your C++ code and your Blueprint assets by finding `.uasset` usages of your native C++ classes.

This is a utility plugin in the **Unreal Neovim Plugin suite**. It depends on [UNL.nvim](https://github.com/taku25/UNL.nvim) as its library and consumes data from [UEP.nvim](https://github.com/taku25/UEP.nvim).

[English](README.md) | [日本語 (Japanese)](README_ja.md)

-----

## ✨ Features

  * **Blueprint Usage Finding**:
      * Provides a `:UEA find_bp_usages` command to find all Blueprint assets (`.uasset`, `.umap`) that inherit from a specific C++ class.
  * **Fast Binary Grep**:
      * Uses [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) to perform extremely fast, non-intrusive searches directly against the binary asset files.
  * **Ecosystem Integration**:
      * Consumes the `uep.get_project_classes` provider from `UEP.nvim` to display a searchable list of all C++ classes in the project.
      * Automatically strips C++ prefixes (`A`, `U`, `F`, etc.) to find the correct `NativeParentClass` name within assets.
  * **UI Integration**:
      * Leverages `UNL.nvim`'s UI abstraction layer to automatically use UI frontends like [Telescope](https://github.com/nvim-telescope/telescope.nvim) and [fzf-lua](https://github.com/ibhagwan/fzf-lua).
      * The default "submit" action copies the selected asset's game path (e.g., `/Game/Blueprints/BP_MyActor`) to the clipboard, ready to be pasted into the Unreal Editor's content browser.

## 🔧 Requirements

  * Neovim v0.11.3 or later
  * [**UNL.nvim**](https://github.com/taku25/UNL.nvim) (**Required**)
  * [**UEP.nvim**](https://github.com/taku25/UEP.nvim) (**Required** for C++ class provider)
  * [rg](https://github.com/BurntSushi/ripgrep) (**Required for asset searching**)
  * **Optional (Strongly recommended for the full experience):**
      * **UI (Picker):**
          * [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
          * [fzf-lua](https://github.com/ibhagwan/fzf-lua)

## 🚀 Installation

Install with your favorite plugin manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  'taku25/UEA.nvim',
  -- UNL.nvim and UEP.nvim are required dependencies
  dependencies = {
     { 'taku25/UNL.nvim', lazy=false, },
     'taku25/UEP.nvim',
     'nvim-telescope/telescope.nvim', -- Optional
  },
  opts = {
    -- UEA-specific settings can be placed here
  },
}
```

## ⚙️ Configuration

This plugin is configured through the setup function of its library, `UNL.nvim`. However, you can also pass `opts` directly to `UEA.nvim` to configure settings in the `UEA` namespace.

Below are the default values related to `UEA.nvim`.

```lua
-- Place inside the spec for UEA.nvim or UNL.nvim in lazy.nvim
opts = {
  -- UEA-specific settings
  uea = {
    -- Section for future UEA-specific settings
  },
  
  -- Asset grep ('rg') configuration
  asset_grep = {
    -- The command to run.
    base_command = "rg",
    
    -- The search pattern template. %s is replaced with the C++ base class name.
    search_pattern_template = "NativeParentClass.*'%s'",
    
    -- Glob patterns for assets to search.
    glob_patterns = {
      "BP_*.uasset",
    }
  },

  -- UI backend settings (inherited from UNL.nvim)
  ui = {
    picker = {
      mode = "auto", -- "auto", "telescope", "fzf_lua", "native"
      prefer = { "telescope", "fzf_lua", "native" },
    },
  },
}
```

## ⚡ Usage

All commands start with `:UEA`.

```viml
" Find Blueprint usages of a C++ class.
:UEA find_bp_usages[!] [ClassName]
```

### Command Details

  * **`:UEA find_bp_usages[!] [ClassName]`**:
      * Finds all Blueprint assets (`.uasset`, `.umap`) that inherit from the specified C++ class.
      * Without `!`: Uses the `[ClassName]` argument if provided, otherwise it uses the word under the cursor.
      * With `!`: Ignores arguments and the word under the cursor, and always opens a picker UI to select a C++ class from the entire project (provided by `UEP.nvim`).
      * **Action**: Pressing `<Enter>` on a selection in the results picker will copy the asset's game path (e.g., `/Game/Blueprints/BP_MyActor`) to the clipboard.

## 🤖 API & Automation Examples

You can use the `UEA.api` module to integrate with other Neovim configurations.

### Keymap Example

Create a keymap to quickly find BP usages for the class under the cursor.

```lua
-- in init.lua or keymaps.lua
-- Find usages for the class under the cursor
vim.keymap.set('n', '<leader>au', function()
  require('UEA.api').find_bp_usages({ has_bang = false })
end, { noremap = true, silent = true, desc = "UEA: Find [A]sset [U]sages (Cursor)" })

-- Find usages by picking from a list of all C++ classes
vim.keymap.set('n', '<leader>aU', function()
  require('UEA.api').find_bp_usages({ has_bang = true })
end, { noremap = true, silent = true, desc = "UEA: Find [A]sset [U]sages (Picker)" })
```

## Others

**Unreal Engine Related Plugins:**

  * **[UEP.nvim](https://github.com/taku25/UEP.nvim)**
      * Analyzes `uproject` files for easy file navigation.
  * **[UEA.nvim](https://www.google.com/search?q=https://github.com/taku25/UEA.nvim)** (This plugin)
      * Finds Blueprint usages of C++ classes.
  * **[UBT.nvim](https://github.com/taku25/UBT.nvim)**
      * Asynchronously run Build, GenerateClangDataBase, and other tasks from Neovim.
  * **[UCM.nvim](https://github.com/taku25/UCM.nvim)**
      * Add and delete classes directly from Neovim.
  * **[ULG.nvim](https://github.com/taku25/ULG.nvim)**
      * View UE logs, live coding status, stat fps, and more within nvim.
  * **[USH.nvim](https://github.com/taku25/USH.nvim)**
      * Interact with `ushell` from nvim.
  * **[neo-tree-unl](https://github.com/taku25/neo-tree-unl.nvim)**
      * Display an IDE-like project explorer.
  * **[tree-sitter for Unreal Engine](https://github.com/taku25/tree-sitter-unreal-cpp)**
      * Provides tree-sitter highlighting, including support for `UCLASS` and other Unreal Engine specific syntax.

## 📜 License

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
