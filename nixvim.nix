# Shared by the Home Manager editor component (modules/components/editor.nix) and the standalone
# `nix run .#nvim` package.
#   lsp      — which LSP servers to enable (each pulls its toolchain: clangd ≈ clang-tools, gopls ≈ go).
#   grammars — treesitter grammar names, or null for nixvim's default (every grammar).
{
  pkgs,
  lsp ? [
    "clangd"
    "gopls"
    "nixd"
  ],
  grammars ? null,
  ...
}:
let
  lib = pkgs.lib;
in
{
  opts = {
    number = true;
    relativenumber = true;
    termguicolors = true;
    signcolumn = "yes";
    updatetime = 200;
    splitright = true;
    splitbelow = true;

    clipboard = "unnamedplus";
    undofile = true;
    cursorline = true;
    scrolloff = 8;
    sidescrolloff = 8;

    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    smartindent = true;

    ignorecase = true;
    smartcase = true;
    incsearch = true;
    hlsearch = true;

    completeopt = [
      "menuone"
      "noselect"
    ];
    timeoutlen = 400;
  };

  extraPlugins = [
    pkgs.vimPlugins.hardtime-nvim
    pkgs.vimPlugins.vim-be-good
  ];

  plugins = {
    web-devicons.enable = true;
    nvim-tree.enable = true;
    telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
    };
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
    }
    // lib.optionalAttrs (grammars != null) {
      grammarPackages = map (g: pkgs.vimPlugins.nvim-treesitter.builtGrammars.${g}) grammars;
    };
    lualine.enable = true;
    gitsigns.enable = true;
    which-key = {
      enable = true;
      settings = {
        preset = "modern";
        win = {
          border = "rounded";
          no_overlap = false;
          padding = [
            1
            2
          ];
          title = true;
          title_pos = "center";
          zindex = 1000;
        };
      };
    };
    lsp = {
      enable = lsp != [ ];
      servers = lib.genAttrs lsp (_: {
        enable = true;
      });
    };
  };

  extraConfigLua = ''
    require("hardtime").setup({
      disable_mouse = true,
      hint = true,
      max_count = 4,
    })
  '';
}
