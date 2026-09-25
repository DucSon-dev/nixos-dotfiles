{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Essential UI, statusline, buffer tabs, and parser plugins
    plugins = with pkgs.vimPlugins; [
      # Interactive hotkey popup guide
      which-key-nvim

      # Clean, minimalist startup dashboard
      alpha-nvim

      # Syntax highlighting and incremental parsing
      nvim-treesitter.withAllGrammars

      # Liquid glass bubble capsule statusline
      lualine-nvim

      # Sleek top bufferline tabs
      bufferline-nvim

      # Thin indentation guides matching editor gutter
      indent-blankline-nvim

      # Nerd Font icon integration
      nvim-web-devicons
    ];

    extraLuaConfig = ''
      -- 1. General editor settings and relative line numbers
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

      -- Disable default intro message
      vim.opt.shortmess:append("I")

      -- Set Space as the global Leader key
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- 2. Theme tokens: Pure Dark Zinc Monochrome & Transparent Glass
      vim.cmd [[
        highlight Normal guibg=NONE guifg=#fafafa
        highlight NormalNC guibg=NONE guifg=#a1a1aa
        highlight LineNr guifg=#52525b guibg=NONE
        highlight CursorLineNr guifg=#fafafa guibg=NONE gui=bold
        highlight CursorLine guibg=#18181b
        highlight SignColumn guibg=NONE
        highlight VertSplit guifg=#27272a guibg=NONE
        highlight StatusLine guibg=NONE guifg=#fafafa
        highlight FloatBorder guifg=#52525b guibg=NONE
        highlight NormalFloat guibg=NONE guifg=#fafafa
        highlight AlphaHeader guifg=#fafafa gui=bold
        highlight AlphaButtons guifg=#a1a1aa
        highlight AlphaShortcut guifg=#60a5fa gui=bold
        highlight AlphaFooter guifg=#52525b
      ]]

      -- 3. Indent-blankline configuration (Thin discreet indentation lines)
      require("ibl").setup({
        indent = { char = "│" },
        scope = { enabled = false },
      })

      -- 4. Top Bufferline configuration (Capsule-styled tabs)
      require("bufferline").setup({
        options = {
          mode = "buffers",
          separator_style = "thin",
          always_show_bufferline = true,
          show_buffer_close_icons = true,
          show_close_icon = false,
          color_icons = true,
          diagnostics = "nvim_lsp",
          offsets = {
            {
              filetype = "NvimTree",
              text = "File Explorer",
              text_align = "left",
              separator = true,
            }
          },
        },
        highlights = {
          fill = { bg = "NONE" },
          background = { bg = "NONE", fg = "#71717a" },
          buffer_selected = { bg = "#27272a", fg = "#fafafa", bold = true },
          separator = { bg = "NONE", fg = "#27272a" },
          separator_selected = { bg = "NONE", fg = "#27272a" },
        },
      })

      -- 5. Lualine Bubble Capsule theme definition
      local colors = {
        bg_glass = "NONE",
        pill_dark = "#18181b",
        pill_active = "#27272a",
        fg_white = "#fafafa",
        fg_muted = "#a1a1aa",
        cyan_accent = "#22d3ee",
        blue_accent = "#60a5fa",
      }

      local bubble_theme = {
        normal = {
          a = { fg = colors.fg_white, bg = colors.pill_active, gui = "bold" },
          b = { fg = colors.fg_white, bg = colors.pill_dark },
          c = { fg = colors.fg_muted, bg = colors.bg_glass },
        },
        insert = {
          a = { fg = "#09090b", bg = colors.cyan_accent, gui = "bold" },
          b = { fg = colors.fg_white, bg = colors.pill_dark },
          c = { fg = colors.fg_muted, bg = colors.bg_glass },
        },
        visual = {
          a = { fg = "#09090b", bg = colors.blue_accent, gui = "bold" },
          b = { fg = colors.fg_white, bg = colors.pill_dark },
          c = { fg = colors.fg_muted, bg = colors.bg_glass },
        },
        inactive = {
          a = { fg = colors.fg_muted, bg = colors.pill_dark },
          b = { fg = colors.fg_muted, bg = colors.pill_dark },
          c = { fg = colors.fg_muted, bg = colors.bg_glass },
        },
      }

      require("lualine").setup({
        options = {
          theme = bubble_theme,
          component_separators = "",
          section_separators = { left = "", right = "" },
          globalstatus = true,
          disabled_filetypes = { statusline = { "alpha" } },
        },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(str) return " " .. str end,
              separator = { left = "", right = "" },
            },
          },
          lualine_b = {
            {
              "filename",
              separator = { left = "", right = "" },
            },
          },
          lualine_c = {
            {
              "branch",
              icon = "",
              separator = { left = "", right = "" },
            },
            {
              "diff",
              separator = { left = "", right = "" },
            },
          },
          lualine_x = {
            {
              "diagnostics",
              sources = { "nvim_diagnostic" },
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
              separator = { left = "", right = "" },
            },
          },
          lualine_y = {
            {
              "progress",
              separator = { left = "", right = "" },
            },
          },
          lualine_z = {
            {
              "location",
              separator = { left = "", right = "" },
            },
          },
        },
      })

      -- 6. Minimalist Alpha-nvim Dashboard configuration
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        [[                               __                ]],
        [[  ___      __    ___   __  __ /\_\    ___ ___    ]],
        [[/' _ `\  /'__`\ / __`\/\ \/\ \\/\ \ /' __` __`\  ]],
        [[/\ \/\ \/\  __//\ \L\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
      }
      dashboard.section.header.opts.hl = "AlphaHeader"

      dashboard.section.buttons.val = {
        dashboard.button("n", "  New File", ":ene <BAR> startinsert <CR>"),
        dashboard.button("w", "  Save File", ":w<CR>"),
        dashboard.button("q", "  Quit Editor", ":qa<CR>"),
      }
      dashboard.section.buttons.opts.hl = "AlphaButtons"

      dashboard.section.footer.val = { "⚡ Neovim initialized in pure Dark Zinc" }
      dashboard.section.footer.opts.hl = "AlphaFooter"

      alpha.setup(dashboard.opts)

      -- 7. Initialize Which-Key for interactive hotkey hints
      local wk = require("which-key")
      wk.setup({
        preset = "modern",
        delay = 200,
        win = {
          border = "rounded",
          padding = { 1, 2 },
        },
      })

      wk.add({
        { "<leader>f", group = "File" },
        { "<leader>fs", "<cmd>w<cr>", desc = "Save File" },
        { "<leader>fq", "<cmd>q<cr>", desc = "Quit Buffer" },
        { "<leader>w", "<cmd>w<cr>", desc = "Quick Save" },
        { "<leader>q", "<cmd>q<cr>", desc = "Quick Quit" },
        { "<leader>b", group = "Buffer" },
        { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer Tab" },
        { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer Tab" },
        { "<leader>bd", "<cmd>bdelete<cr>", desc = "Delete Buffer" },
      })
    '';
  };
}
