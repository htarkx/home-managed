{ pkgs, ... }:
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

    completeopt = [ "menuone" "noselect" ];
    timeoutlen = 400;
  };

  extraPlugins = [
    pkgs.vimPlugins.copilot-vim
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
    };
    lualine.enable = true;
    gitsigns.enable = true;
    which-key.enable = true;
    lsp = {
      enable = true;
      servers = {
        clangd.enable = true;
        gopls.enable = true;
        nil_ls.enable = true;
      };
    };
  };
}
