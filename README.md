# UEA.nvim

# Unreal Engine Asset Inspector 💓 Neovim

`UEA.nvim` is a Neovim plugin designed to inspect Unreal Engine assets and find their relationships. It bridges the gap between your C++ code and your Blueprint assets by finding `.uasset` usages of your native C++ classes and scanning asset references.

This is a utility plugin in the **Unreal Neovim Plugin suite**. It depends on [UNL.nvim](https://github.com/taku25/UNL.nvim) as its library and consumes data from [UEP.nvim](https://github.com/taku25/UEP.nvim).

[English](README.md) | [日本語 (Japanese)](README_ja.md)

-----

## ✨ Features

  * **Blueprint Usage Finding**:
      * `:UEA find_bp_usages` finds all Blueprint assets (`.uasset`, `.umap`) that inherit from a specific C++ class.
  * **Asset Reference Finding**:
      * `:UEA find_references` finds assets that reference a specific asset (similar to the "Referencers" view in UE).
  * **Asset Dependency Finding**:
      * `:UEA find_dependencies` finds internal dependencies of a binary asset (similar to the "Dependencies" view in UE).
  * **Binary String Grep**:
      * `:UEA grep_string` searches for arbitrary strings (GameplayTags, socket names, etc.) within binary assets.
  * **Editor Integration**:
      * `:UEA show_in_editor` syncs the Unreal Editor Content Browser to the selected asset via Web Remote Control.
  * **System Integration**:
      * `:UEA system_open` opens the asset's location in the OS file explorer (Explorer/Finder).
  * **Code Lens**:
      * Displays the number of Blueprint references as virtual text next to C++ class definitions. (Requires `rg`)
  * **Fast Binary Scanning**:
      * Uses [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd) for extremely fast, non-intrusive asset scanning.
  * **Ecosystem Integration**:
      * Consumes C++ class data from `UEP.nvim`.
      * Automatically strips C++ prefixes (`A`, `U`, `F`, etc.) to correctly match asset data.
      * Intelligent exclusion of UE5 OFPA (One File Per Actor) folders to reduce noise.

## 🔧 Requirements

  * Neovim v0.11.3 or later
  * [**UNL.nvim**](https://github.com/taku25/UNL.nvim) (**Required**)
  * [**UEP.nvim**](https://github.com/taku25/UEP.nvim) (**Required** for C++ class provider)
  * [**tree-sitter-unreal-cpp**](https://github.com/taku25/tree-sitter-unreal-cpp) (**Required** Tree sitter Unreal C++)
  * [rg](https://github.com/BurntSushi/ripgrep) (**Required for asset searching**)
  * [fd](https://github.com/sharkdp/fd) (**Required for asset listing**)
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
     'nvim-telescope/telescope.nvim', -- Option
    { 
      'nvim-treesitter/nvim-treesitter',
      branch = "main",
      config = function(_, opts)
        vim.api.nvim_create_autocmd('User', { pattern = 'TSUpdate',
          callback = function()
            local parsers = require('nvim-treesitter.parsers')
            parsers.cpp = {
              install_info = {
                url  = 'https://github.com/taku25/tree-sitter-unreal-cpp',
                revision  = '89f3408b2f701a8b002c9ea690ae2d24bb2aae49',
              },
            }
          end
        })
        local langs = { "c", "cpp",  }
        require("nvim-treesitter").install(langs)
        local group = vim.api.nvim_create_augroup('MyTreesitter', { clear = true })
        vim.api.nvim_create_autocmd('FileType', {
          group = group,
          pattern = langs,
          callback = function(args)
            vim.treesitter.start(args.buf)
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end,
        })
      end
    }
    
  },
  opts = {
    -- UEA-specific settings can be placed here
  },
}
````

## ⚙️ Configuration

This plugin is configured through the setup function of its library, `UNL.nvim`. However, you can also pass `opts` directly to `UEA.nvim` to configure settings in the `UEA` namespace.

Below are the default values related to `UEA.nvim`.

```lua
-- Place inside the spec for UEA.nvim or UNL.nvim in lazy.nvim
opts = {
  -- Settings for Code Lens (virtual text)
  code_lens = {
    enable = true, -- Enable/disable automatic Code Lens
  },
  
  -- Asset grep ('rg') configuration
  asset_grep = {
    -- The command to run.
    base_command = "rg",
    
    search_pattern_template = "%s",
    
    lens_inheritance_pattern = "NativeParentClass.*'.*%s'",
    
    -- Glob patterns for assets to search.
    glob_patterns = {
      "*.uasset",
      "*.umap",
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

" Find assets referencing a specific asset.
:UEA find_references[!] [AssetPath]

" Find internal dependencies of an asset.
:UEA find_dependencies[!] [AssetPath]

" Show parent class information for a binary asset.
:UEA find_bp_parent[!] [AssetPath]

" Grep for a string inside assets.
:UEA grep_string[!] [Query]

" Sync the Unreal Editor Content Browser to the asset.
:UEA show_in_editor[!] [AssetPath]

" Open the asset's location in system explorer.
:UEA system_open[!] [AssetPath]

" Copy the Unreal Object Path of an asset to clipboard.
:UEA copy_reference[!]

" Manually refresh Code Lens.
:UEA refresh_lens
```

### Command Details

  * **`:UEA find_bp_usages[!] [ClassName]`**:
      * Finds all Blueprint assets (`.uasset`, `.umap`) that inherit from the specified C++ class.
      * `!` (Bang): Ignores arguments and opens a picker UI to select a C++ class from the entire project (provided by `UEP.nvim`).
      * `[ClassName]`: If omitted, uses the word under the cursor (`<cword>`).
  * **`:UEA find_references[!] [AssetPath]`**:
      * Finds other assets that reference the specified asset.
      * `!` (Bang): Opens a picker UI to select an asset from the Content directory.
      * `[AssetPath]`: If omitted, checks the clipboard for an asset path (e.g., `/Game/BP_Hero`). If empty, prompts for input.
  * **`:UEA find_dependencies[!] [AssetPath]`**:
      * Finds assets that the specified asset depends on (Reference Viewer: Dependencies).
      * Usage is the same as `:UEA find_references`.
  * **`:UEA grep_string[!] [Query]`**:
      * Searches for an arbitrary string within binary assets in the Content directory. Useful for finding GameplayTags, socket names, or property names.
      * `!` (Bang): Prompts for the search query.
      * `[Query]`: If omitted, uses the word under the cursor.
  * **`:UEA find_bp_parent[!] [AssetPath]`**:
      * Extracts and displays the parent class information (`NativeParentClass`) from a binary asset file.
      * Usage is the same as `:UEA find_references`.
  * **`:UEA show_in_editor[!] [AssetPath]`**:
      * Sends a command to the running Unreal Editor (via Web Remote Control) to sync the Content Browser to the specified asset.
      * Requires "Remote Control API" plugin enabled in UE.
      * Usage is the same as `:UEA find_references`.
  * **`:UEA system_open[!] [AssetPath]`**:
      * Opens the OS file explorer (Explorer/Finder) with the asset file selected.
      * Usage is the same as `:UEA find_references`.
  * **`:UEA copy_reference[!]`**:
      * Opens a picker to select an asset and copies its Unreal Object Path (e.g., `/Game/BP_Hero.BP_Hero_C`) to the clipboard.
  * **`:UEA refresh_lens`**:
      * Manually triggers a refresh of the Code Lens (virtual text showing BP usage counts).

## 🤖 API & Automation Examples

You can use the `UEA.api` module to integrate with other Neovim configurations.

```lua
local uea_api = require("UEA.api")

-- Find usages for the class under the cursor
vim.keymap.set('n', '<leader>au', function()
  uea_api.find_bp_usages({ has_bang = false })
end, { noremap = true, silent = true, desc = "UEA: Find Asset Usages (Cursor)" })

-- Find references for the asset path in clipboard
vim.keymap.set('n', '<leader>ar', function()
  uea_api.find_references({ has_bang = false })
end, { noremap = true, silent = true, desc = "UEA: Find References (Clipboard)" })
```

### API Functions

  * `uea_api.find_bp_usages({opts})`
  * `uea_api.find_references({opts})`
  * `uea_api.find_dependencies({opts})`
  * `uea_api.find_bp_parent({opts})`
  * `uea_api.grep_string({opts})`
  * `uea_api.show_in_editor({opts})`
  * `uea_api.system_open({opts})`
  * `uea_api.copy_reference({opts})`
  * `uea_api.refresh_lens()`

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
