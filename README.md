# home_managed

Home Manager configuration optimized for a "computer networking student" toolkit with cross-platform defaults.

## Fresh Machine Setup (macOS/Linux)

Assume a new machine with no Nix installed.

1. Install Nix (official installer)

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

2. Restart your shell/session, then enable flakes

```bash
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << 'EOF'
experimental-features = nix-command flakes
EOF
```

3. Apply this repo (bootstrap with `nix run`, no pre-installed `home-manager` needed)

```bash
cd /home/<user>/codes/home-managed
nix run github:nix-community/home-manager -- switch -b backup-$(date +%s) --flake .#current --impure
```

4. Configure Git identity (required for commits)

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Verify:

```bash
git config --global --list | rg "user.name|user.email"
```

Notes:

- Works for both macOS and Linux.
- `--impure` is required for this flake because `homeConfigurations.current` reads `USER`/`HOME` from environment variables.
- Using `nix run` for first activation avoids `home-manager` binary conflicts in `nix profile`.

### Linux + VS Code Terminal (important on fresh machines)

On Linux fresh machines, VS Code integrated terminal may still open `bash` by default even after Home Manager enables `zsh`.
This is because VS Code has its own terminal profile settings and does not always follow your login shell.

Option A (recommended): manage VS Code terminal profile manually

```json
// ~/.vscode-server/data/Machine/settings.json (Remote SSH)
// or ~/.config/Code/User/settings.json (local Linux desktop)
{
  "terminal.integrated.defaultProfile.linux": "zsh",
  "terminal.integrated.profiles.linux": {
    "zsh": {
      "path": "/home/<user>/.nix-profile/bin/zsh",
      "args": ["-l"]
    }
  }
}
```

Option B: manage this file with Home Manager as `xdg.configFile`/`home.file`.
This is possible, but many users prefer keeping editor-specific settings outside this repo to avoid overriding personal IDE preferences across machines.

## Usage

Current machine (auto-detect USER/HOME, requires impure):

```bash
home-manager switch --flake .#current --impure
```

> If `home-manager` is not in PATH, use `nix run github:nix-community/home-manager -- switch --flake .#current --impure` instead.

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

**Performance benchmarking**

Cross-platform: `iperf3` (network throughput)

Linux-only: `sysstat` (`mpstat`), `sysbench` (CPU/memory), `fio` (disk I/O)

**Security / traffic replay tools**

`netcat`, `socat`, `mitmproxy`

**Programming runtimes**

`python3`, `python3Packages.ipython`, `go`

**OS-specific add-ons**

macOS gains `gnuplot`; Linux gains `iproute2`, `ethtool`, `bridge-utils`, `sysstat`, `sysbench`, `fio`.

### Linux benchmark shortcuts

Linux profile provides these aliases:

- `bench-steal` -> `mpstat -P ALL 1 30`
- `bench-cpu` -> `sysbench cpu --threads=$(nproc) --time=60 run`
- `bench-mem` -> `sysbench memory --memory-total-size=20G run`
- `bench-disk` -> `fio --name=randrw --filename=/tmp/fio.test --size=4G --bs=4k --rw=randrw --iodepth=32 --numjobs=4 --runtime=60 --time_based --group_reporting`
- `bench-net-server` -> `iperf3 -s`

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

## System Sysctl (Ubuntu / non-NixOS)

This repo is primarily Home Manager, so system-level kernel/network sysctls are
provided as templates instead of being applied automatically.

Use `templates/sysctl/99-bbr.conf` for:

- TCP BBR (`net.ipv4.tcp_congestion_control = bbr`)
- `fq` qdisc
- TCP/UDP buffer tuning baseline (useful for QUIC/Hysteria and bursty traffic)

Install and apply:

```bash
sudo cp /home/<user>/codes/home-managed/templates/sysctl/99-bbr.conf /etc/sysctl.d/99-bbr.conf
sudo sysctl --system
```

Verify:

```bash
sysctl net.core.default_qdisc
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.rmem_max net.core.wmem_max
sysctl net.ipv4.tcp_rmem net.ipv4.tcp_wmem
sysctl net.ipv4.udp_rmem_min net.ipv4.udp_wmem_min
sysctl net.core.netdev_max_backlog
```
