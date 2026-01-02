# home_managed

Home Manager configuration optimized for a "computer networking student" toolkit with cross-platform defaults.

## Usage

Current machine (auto-detect USER/HOME, requires impure):

```bash
home-manager switch --flake .#current --impure
```

> Ensure the `home-manager` CLI is installed (e.g., `nix profile install github:nix-community/home-manager` or via your preferred channel) so the command above is available.

Fixed profiles (optional):

```bash
nix flake show
```

## Layout

- `flake.nix`: wires Home Manager profiles and automatically picks `home/darwin.nix` or `home/linux.nix` based on the build host.
- `home/common.nix`: everything shared across macOS/Linux (shells, editor, base tooling).
- `home/darwin.nix`: macOS-only extras (currently `gnuplot`).
- `home/linux.nix`: Linux-only extras (`iproute2`, `ethtool`, `bridge-utils`), enables `targets.genericLinux`, and includes Zsh hooks for VS Code Remote terminals to pick up Nix/Home Manager env reliably.
- `nixvim.nix`: drives both the Home Manager nixvim module and the standalone `packages.nvim`.
- `dotfiles/.p10k.zsh`: powerlevel10k theme referenced from the Zsh init script.

## Customize

- Update `flake.nix` if you want to rename/remove the fixed profiles or add more OS-specific modules.
- Extend the shared toolkit / shells / tmux / direnv in `home/common.nix`.
- Modify macOS-only logic in `home/darwin.nix` and Linux-only logic in `home/linux.nix`.
- Tweak editor behavior in `nixvim.nix`; changes propagate to both Home Manager and the packaged `nvim`.
- Keep prompt tweaks inside `dotfiles/.p10k.zsh`.

## Default toolkit (curated layers)

**Base GNU userland (platform parity)**

`coreutils`, `findutils`, `gnugrep`, `gnused`, `gawk`, `less`, `tree`, `watch`

**Daily CLI muscle memory**

`ripgrep`, `fd`, `bat`, `eza`, `fzf`, `dust`, `ncdu`, `duf`, `git-open`, `btop`, `fastfetch`, `inetutils`, `lazygit`

**Networking diagnostics**

`tcpdump`, `wireshark`, `iperf3`, `mtr`, `nmap`, `dnsutils`, `curl`, `wget`, `httpie`, `openssl`

**Security / traffic replay tools**

`netcat`, `socat`, `mitmproxy`

**Programming runtimes**

`python3`, `python3Packages.ipython`, `go`

**OS-specific add-ons**

macOS gains `gnuplot`; Linux gains `iproute2`, `ethtool`, `bridge-utils`.

## Zsh Configuration (English, exhaustive)

The Home Manager config enables Zsh and wires up prompt/theme, plugins, and helper tools.

### Core Zsh settings

- `programs.zsh.enable = true`
- `programs.zsh.enableCompletion = true`
- `programs.zsh.initContent`:
  - `bindkey -v` (vi keybindings)
  - sources `~/.p10k.zsh` if present
  - loads micromamba Zsh hook when available
- Linux-only: `programs.zsh.envExtra` re-sources `hm-session-vars.sh` when `NIX_PROFILES` is missing (works around VS Code Remote env propagation quirks).

### Oh My Zsh plugins

Enabled via `programs.zsh.oh-my-zsh.plugins`: `git`, `z`, `fzf`, `docker`, `kubectl`, `history-substring-search`

### Extra Zsh plugins (non-OMZ)

Enabled via `programs.zsh.plugins`:

- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `fzf-tab`
- `powerlevel10k` (theme)

### Related tools enabled

- `programs.fzf.enable = true`
- `programs.direnv.enable = true`
- `programs.direnv.nix-direnv.enable = true`
- `programs.nixvim = import ../nixvim.nix { inherit pkgs; };`
- Custom Zsh helpers `hms()` / `hms-fast()` wrap `home-manager switch --flake .#current --impure` (with optional `--no-build-output`) and auto-`cd` to the repo root via `git rev-parse`.

### Where to edit

All of the above lives in `home/common.nix`.
