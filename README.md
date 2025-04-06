# C++Live extension for Neovim

What [vscode-cpp-live](https://github.com/segfault-survivor/vscode-cpp-live) does, but for [Neovim](https://github.com/neovim/neovim).

## Known Issues

- **BufWritePre formatting incompatibility:**  
  The plugin automatically saves the buffer on every change using the `TextChanged` and `TextChangedI` events. This automatic save behavior interferes with hooks such as `BufWritePre` that rely on a manual or specific save event. As a result, if you configure Lua LSP formatting (e.g., with `vim.lsp.buf.format` or similar commands) on `BufWritePre`, the formatting may not work as expected.  
  **Workaround:**  
  - Avoid setting up your LSP or formatting commands on `BufWritePre` if you are using this plugin.
  - Use `:CppLiveStop` to disable the plugin.
  - Override `process.done` and `enable` functions to format on successful build and skip once (only if formatting did the modification).

## Installation

* [Lazy.nvim](https://lazy.folke.io/)

```lua

return {
  "segfault-survivor/nvim-cpp-live",
  opts = {
    debounce = 0,

    filetypes = {"cpp"},

    output = {
        max_lines = 1000,
        window_config = { split = "right", width = 42, win = 0 }
    },

    process = {
        jobify = true
    }
  }
}
```

# Usage
Once installed, you can control the plugin with the following commands:

* `:CppLiveStart` - Start watching C++ file changes.
* `:CppLiveStop` - Stop the watcher.

## Configuration Options

* `debounce` (number, default: 0):

    Delay in milliseconds to wait after a keystroke before triggering the process.

* `filetypes` (table, default: {"cpp"}):

    A list of filetypes to watch.

* `output.max_lines` (number, default: 1000):

    Maximum number of lines allowed in the output buffer.

* `output.window_config` (table, Default: { split = "right", width = 42, win = 0 }):

    Configuration table for opening the output window, see `:h nvim_open_win`.

* `jobify` (boolean/table/function, default: true):

    Controls how the process is started. For Windows, enabling jobification uses a PowerShell `script/jobify.ps1`.

# Example

After installing the plugin:

```
    git clone https://github.com/segfault-survivor/vscode-cpp-live.git
    cd vscode-cpp-live
    cd example
    nvim main-windows.cpp
```
Then in NeoVim:
```
    :CppLiveStart
    49G
    7x
    <wait>
```
Keep editing the file to see how fast things go with [Cut!](https://github.com/segfault-survivor/cut)
