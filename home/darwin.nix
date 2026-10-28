{ pkgs, lib, ... }:
{
  # Shared keys live in common.nix; see vscode.nix for how settings.json is written.
  my.vscode.settings = {
    "git.autofetch" = true;
    "git.confirmSync" = false;
    "git.enableSmartCommit" = true;
    "python.defaultInterpreterPath" = "/opt/anaconda3/envs/myenv/bin/python";
    "C_Cpp.default.compilerPath" = "/opt/homebrew/bin/gcc-14";
    "code-runner.runInTerminal" = true;
    "cmake.options.statusBarVisibility" = "icon";
    "solidity.telemetry" = true;
    "explorer.confirmDelete" = false;
    "workbench.secondarySideBar.defaultVisibility" = "hidden";
    "chatgpt.openOnStartup" = true;
    "go.toolsEnvVars" = { };
    "docker.extension.enableComposeLanguageServer" = false;
    "editor.fontFamily" = "JetBrainsMono Nerd Font";
    "terminal.integrated.profiles.linux" = {
      bash = {
        path = "bash";
        icon = "terminal-bash";
      };
      zsh.path = "zsh";
      "zsh (login)" = {
        path = "zsh";
        args = [ "-l" ];
      };
      fish.path = "fish";
      tmux = {
        path = "tmux";
        icon = "terminal-tmux";
      };
      pwsh = {
        path = "pwsh";
        icon = "terminal-powershell";
      };
    };
    "extensions.experimental.affinity" = {
      "asvetliakov.vscode-neovim" = 1;
    };
  };

  home.packages = lib.mkAfter (
    with pkgs;
    [
      gnuplot
      nicotine-plus
    ]
  );
}
