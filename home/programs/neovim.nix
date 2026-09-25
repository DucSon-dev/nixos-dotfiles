{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Explicitly adopt new runtime behavior to silence upstream deprecation warnings
    withRuby = false;
    withPython3 = false;

    # Essential UI and interactive key helper plugins
    plugins = with pkgs.vimPlugins; [
      # Interactive hotkey popup guide
      which-key-nvim

      # Clean, minimalist startup dashboard replacing default intro
      alpha-nvim

      # Syntax highlighting and incremental parsing
      nvim-treesitter.withAllGrammars

      # Minimal statusline matching Zinc theme
      lualine-nvim

      # Nerd Font icon integration
      nvim-web-devicons
    ];

    # Modern initLua syntax replacing deprecated extraLuaConfig
    initLua = ''
      -- 1. General settings and hybrid line numbers
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.autoindent = true
      vim.opt.wrap = false
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.cursorline = true
      vim.opt.termguicolors = true
      vim.opt.signcolumn = "yes"
      vim.opt.clipboard = "unnamedplus"

      -- Disable default startup intro screen
      vim.opt.shortmess:append("I")

      -- Set Space as the global Leader key
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- 2. Color palette synchronized with shadcn Dark Zinc & Kitty (#09090b)
      vim.cmd [[
        highlight Normal guibg=#09090b guifg=#fafafa
        highlight NormalNC guibg=#09090b guifg=#a1a1aa
        highlight LineNr guifg=#52525b guibg=NONE
        highlight CursorLineNr guifg=#fafafa guibg=NONE gui=bold
        highlight CursorLine guibg=#18181b
        highlight SignColumn guibg=NONE
        highlight VertSplit guifg=#27272a guibg=NONE
        highlight StatusLine guibg=#18181b guifg=#fafafa
        highlight FloatBorder guifg=#52525b guibg=#09090b
        highlight NormalFloat guibg=#09090b guifg=#fafafa
        highlight AlphaHeader guifg=#fafafa gui=bold
        highlight AlphaButtons guifg=#a1a1aa
        highlight AlphaShortcut guifg=#3b82f6 gui=bold
        highlight AlphaFooter guifg=#52525b
      ]]

      -- 3. Minimalist Alpha-nvim Dashboard configuration
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- Monochrome minimal ASCII art banner
      dashboard.section.header.val = {
        [[                               __                ]],
        [[  ___      __    ___   __  __ /\_\    ___ ___    ]],
        [[/' _ `\  /'__`\ / __`\/\ \/\ \\/\ \ /' __` __`\  ]],
        [[/\ \/\ \/\  __//\ \L\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
      }
      dashboard.section.header.opts.hl = "AlphaHeader"

      -- Interactive buttons with quick learning hints
      dashboard.section.buttons.val = {
        dashboard.button("n", "  New File", ":ene <BAR> startinsert <CR>"),
        dashboard.button("w", "  Save File", ":w<CR>"),
        dashboard.button("q", "  Quit Editor", ":qa<CR>"),
      }
      dashboard.section.buttons.opts.hl = "AlphaButtons"

      -- Subtle footer info
      dashboard.section.footer.val = { "⚡ Neovim initialized in pure Dark Zinc" }
      dashboard.section.footer.opts.hl = "AlphaFooter"

      alpha.setup(dashboard.opts)

      -- 4. Initialize Lualine statusline
      require("lualine").setup({
        options = {
          theme = "auto",
          component_separators = "|",
          section_separators = "",
        }
      })

      -- 5. Initialize Which-Key for interactive hotkey hints
      local wk = require("which-key")
      wk.setup({
        preset = "modern",
        delay = 200,
        win = {
          border = "rounded",
          padding = { 1, 2 },
        },
      })

      -- Register primary action groups and learning hints
      wk.add({
        { "<leader>f", group = "File" },
        { "<leader>fs", "<cmd>w<cr>", desc = "Save File" },
        { "<leader>fq", "<cmd>q<cr>", desc = "Quit Buffer" },
        { "<leader>w", "<cmd>w<cr>", desc = "Quick Save" },
        { "<leader>q", "<cmd>q<cr>", desc = "Quick Quit" },
        { "<leader>b", group = "Buffer" },
        { "<leader>bn", "<cmd>bnext<cr>", desc = "Next Buffer" },
        { "<leader>bp", "<cmd>bprevious<cr>", desc = "Previous Buffer" },
      })
    '';
  };
}
