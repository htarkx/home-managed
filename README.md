# home_managed

Home Manager configuration optimized for a "computer networking student" toolkit with cross-platform defaults.

Everything beyond a core shell is an **optional component** (`my.<component>.enable`). Pick a preset
(`minimal` / `dev` / `full`) or write a per-machine `hosts/<hostname>.nix`.

| Preset | What it adds | Download | Peak `/nix/store` |
|---|---|---|---|
| `minimal` (default on fresh machines) | core shell + lean nixvim | ~0.3 GiB | ~1.6 GiB |
| `dev` | + LSPs, node/micromamba/nixd, net CLI, k8s clients, TUI apps, nix-index, VS Code, Claude Code | ~0.75 GiB | ~4.3 GiB |
| `full` | everything, identical to the pre-component setup | ~1.3 GiB | ~7.7 GiB |

Measured for x86_64-linux against cache.nixos.org: the Home Manager closure plus build-time inputs of
the few local builds (nixvim wrapper, docs). A fresh machine's whole `/nix/store` ends up larger — about
3.7 GB after `minimal` in an Ubuntu container — since it also holds Nix itself, the flake inputs and
nixpkgs sources; `nix-collect-garbage -d` reclaims part of it afterwards.

`.#current` (what the setup script and a bare `hms` apply) keeps each machine on what it already has
(`lib/current.nix`):

1. **Recorded** — every switch snapshots its component selection to
   `~/.local/state/home-managed/selection.json`; `current` re-applies exactly that, however it was chosen
   (preset, host file, `hms dev`).
2. **Inferred** — a machine set up before snapshots existed: the components are derived from the programs
   in its active generation's `home-path/bin` (e.g. `cilium` → `my.k8s.cilium`, only `tshark` →
   `wireshark = "cli"`, no `bpftrace` → eBPF off).
3. **Fresh** — nothing applied yet: `minimal`.

Evaluation prints which one applied (`trace: home-managed .#current: ...`). To change a machine, switch
to another target once (`hms dev`) or add a host file; that becomes the new snapshot.

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

3. Apply this repo (bootstrap with `nix run`, no pre-installed `home-manager` needed). Pick a target:
   `minimal`, `dev`, `full`, or your own `hosts/<name>.nix` (see [Components](#components)).

```bash
cd /home/<user>/codes/home-managed
nix run github:nix-community/home-manager -- switch -b backup-$(date +%s) --flake .#minimal --impure
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
- `--impure` is required for this flake because every configuration reads `USER`/`HOME` from environment variables.
- Using `nix run` for first activation avoids `home-manager` binary conflicts in `nix profile`.

### Linux + VS Code Terminal (important on fresh machines)

On Linux fresh machines, VS Code integrated terminal may still open `bash` by default even after Home Manager enables `zsh`.
This is because VS Code has its own terminal profile settings and does not always follow your login shell.

This repo declares that profile for you (`modules/platform/linux.nix`, written to
`~/.vscode-server/data/Machine/settings.json` for Remote SSH) when the `vscode` component is on, see below.
Server extensions are installed on `switch` once VS Code Server exists; on a machine that has never been
connected to, the step is skipped with a warning (run `hms` again after the first Remote SSH session).

### VS Code settings (single source of truth)

`modules/components/vscode.nix` owns `settings.json` (only when `my.vscode.enable`). Every module declares
keys under `my.vscode.settings` (shared ones in `components/vscode.nix`, OS-specific ones in
`modules/platform/{darwin,linux}.nix`); the module system merges them and rejects one key defined twice
with different values.

On `home-manager switch` the declared keys are merged into the real file with `jq`: declared keys win,
keys written by VS Code, extensions or the settings UI are kept. The file stays writable, so VS Code never
keeps unsaved settings around (a read-only `home.file` symlink caused a "save settings.json?" prompt on
every quit).

- `vscode-settings-drift` — keys VS Code added (`only_in_settings_json`) and declared keys changed in the
  UI (`differs_from_declaration`, reset on the next switch). Promote what you want to keep into Nix.
- `my.vscode.prune = true;` — drop undeclared keys on every switch (fully declarative).
- A `settings.json` with comments (JSONC) cannot be merged; it is backed up to `settings.json.bak-<time>`
  and rewritten from the declaration.

## Usage

```bash
hms                 # hosts/$(hostname -s).nix if it exists, otherwise .#current (see above)
hms dev             # or any homeConfigurations name: minimal, full, k3s, <host>; its selection becomes the new current
```

`hms` / `hms-fast` wrap `home-manager switch --flake .#<target> --impure` (see Zsh section). Without them:

```bash
home-manager switch --flake .#dev --impure
```

> If `home-manager` is not in PATH, use `nix run github:nix-community/home-manager -- switch --flake .#dev --impure` instead.

Targets (`nix flake show`): `minimal`, `dev`, `full`, `current` (this machine's recorded / inferred selection, `minimal` when fresh), `k3s` (= `full` + cilium-cli),
`user-linux` / `user-mac` / `user-mac-intel` (`full` pinned to a system), `$USER` (= `full`), and one per
`hosts/*.nix`.

## Components

Each component is a module in `modules/components/` that declares `my.<name>.enable` (off by default) and
carries its own packages, aliases, zsh snippets and activation steps — turning one off leaves no dangling
aliases behind. Sizes are what the component adds on top of core (x86_64-linux).

| Option | Contents | Adds |
|---|---|---|
| *(core, always)* | zsh + plugins + p10k, tmux, fzf, zoxide, atuin, direnv, GNU userland, rg/fd/bat/eza/dust/ncdu/duf/btop, gh, git-open, lazygit, curl/wget/openssl; Linux: iproute2, ethtool, bridge-utils | ~0.4 GiB |
| `my.editor.enable` | nixvim. `lsp = [ "clangd" "gopls" "nixd" ]` (default `[ ]`), `grammars` (default: ~20 common languages; `null` = all), `providers` (Ruby/Python 3 hosts, default off) | small–~1 GiB with all LSPs |
| `my.net.enable` | tcpdump, iperf3, mtr, trippy, nexttrace, nmap, dig, httpie, netcat, socat, wireguard-tools, inetutils; `wireshark = "none" \| "cli" \| "gui"` (default `cli`) | ~0.23 GiB (+1.4 GiB for `gui`) |
| `my.perf.enable` (Linux) | sysbench, fio, dool, sysstat, atop, nmon, iotop, ioping, `bench-*` aliases | ~0.2 GiB |
| `my.ebpf.enable` (Linux) | bpftrace, bcc, bpftools, bpfmon, bcc aliases | ~1.7 GiB |
| `my.k8s.enable` | kubectl; Linux: helm, k9s, `k3s-*` aliases. `cilium = true` adds cilium-cli | ~0.3 GiB |
| `my.cloud.enable` | google-cloud-sdk, ansible, kops, step-cli (each toggleable: `gcloud`, `ansible`, `kops`, `step`) | ~1.0 GiB |
| `my.dev.enable` | nodejs_20 (npm prefix `~/.local/share/npm-global`), micromamba (`mm*` aliases), nixd, nixfmt | ~1.2 GiB |
| `my.tui.enable` | yazi, zellij, pueue, navi (Alt-g widget), tealdeer, glances, fastfetch, tig, gitui; `yaziPreviews` pulls ffmpeg/imagemagick/poppler (~1 GiB) | ~0.3 GiB without previews |
| `my.ops.enable` | smartmontools; Linux: borgbackup | ~0.15 GiB |
| `my.nixIndex.enable` | nix-index with prebuilt database, `,` (comma) | small |
| `my.vscode.enable` | settings.json merge, `vscode-settings-drift`; Linux: VS Code Server extensions | small |
| `my.claude.enable` | installs Claude Code via claude.ai/install.sh on activation | small |
| `my.docs.enable` | Home Manager / nixvim man pages (building them pulls pandoc) | build-time |
| `my.gpu.enable` (Linux) | `targets.genericLinux.gpu` — mesa/LLVM for Nix GUI/GL apps on non-NixOS | ~0.8 GiB |

Other knobs: `my.repoPath` (default `~/codes/home-managed`) is where the `k3s-*` aliases look for scripts.

### Per-machine selection

Copy `hosts/_example.nix` to `hosts/<short hostname>.nix` and commit it (flakes only see tracked files):

```nix
{ lib, ... }:
{
  imports = [ ../presets/minimal.nix ];
  my.net.enable = true;
  my.perf.enable = true;
}
```

Presets set everything with `lib.mkDefault`, so a host file can override any of it. `hms` with no
argument picks the host file that matches `hostname -s`. Linux-only components fail evaluation with an
assertion if enabled on macOS.

## Layout

- `flake.nix`: builds every target with `mkHome { modules = [ preset or host ]; }` and picks `modules/platform/darwin.nix` or `linux.nix` from the build host.
- `modules/core/`: always-on base (`base.nix` packages/aliases/options, `shell.nix` zsh/bash/session, `tmux.nix`).
- `modules/components/`: optional components (table above).
- `modules/platform/darwin.nix`: macOS-only bits (VS Code keys, `gnuplot`, `nicotine-plus`).
- `modules/platform/linux.nix`: `targets.genericLinux`, `iproute2`/`ethtool`/`bridge-utils`, `ports()` helper, VS Code Server terminal profile.
- `presets/`: `minimal.nix` ⊂ `dev.nix` ⊂ `full.nix`.
- `lib/current.nix`: resolves `.#current` (recorded → inferred → minimal); `modules/core/selection.nix` writes the snapshot.
- `hosts/`: per-machine selections; each file becomes a flake target (`_`-prefixed files are ignored).
- `scripts/k3s/*.sh`: imperative k3s lifecycle helpers; use `enable-all.sh` to bring the stack up and `disable-all.sh` to tear it fully down.
- `nixvim.nix`: shared by the editor component and the standalone `packages.nvim` (which keeps all LSPs and grammars).
- `dotfiles/.p10k.zsh`: powerlevel10k theme referenced from the Zsh init script.

### k3s shortcuts

With `my.k8s.enable` on Linux:

- `k3s-install`
- `k3s-cilium`
- `k3s-monitoring`
- `k3s-up`
- `k3s-down`
- `k3s-status`
- `k3s-monitoring-status`
- `k3s-grafana-pass`
- `k3s-grafana`

### Monitoring Stack Boundary

The monitoring workload lives here:

- `values/k3s/monitoring.yaml` configures `kube-prometheus-stack`
- `scripts/k3s/monitoring-deploy.sh` deploys the Helm release
- `scripts/k3s/bootstrap-authentik-grafana-oauth.sh` creates the Authentik Grafana OAuth provider and the Kubernetes Secret consumed by Grafana

The public/internal edge entry for Grafana lives in the sibling `K8s-Cert` repo:

- `K8s-Cert/manifests/ingress/internal-edge-ingress.yaml` owns the `ob.htark.dev` Ingress rule
- `K8s-Cert/manifests/ingress/internal-edge-certificates.yaml` owns the `ob.htark.dev` certificate
- `K8s-Cert/manifests/ingress/observability-routers.yaml` owns the `ob-router` bridge to `monitoring-grafana.monitoring.svc.cluster.local`

Grafana is intentionally configured as Authentik OIDC-only: the local login form,
anonymous auth, and basic auth are disabled in `values/k3s/monitoring.yaml`.

## Customize

- New optional tool: add it to the matching `modules/components/*.nix`, or create a component (copy one, add it to `modules/default.nix`, and enable it in a preset).
- Always-on tooling / shells / tmux / direnv live in `modules/core/`.
- Modify macOS-only logic in `modules/platform/darwin.nix` and Linux-only logic in `modules/platform/linux.nix`.
- Tweak editor behavior in `nixvim.nix`; changes propagate to both Home Manager and the packaged `nvim`.
- Keep prompt tweaks inside `dotfiles/.p10k.zsh`.

### Linux benchmark shortcuts

With `my.perf.enable`:

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
  - loads micromamba Zsh hook (`dev` component)
- Linux-only: `programs.zsh.envExtra` re-sources `hm-session-vars.sh` when `NIX_PROFILES` is missing (works around VS Code Remote env propagation quirks).

### Oh My Zsh plugins

Sourced directly from `pkgs.oh-my-zsh` (no `oh-my-zsh.sh`): `git`, `fzf`, `docker`, `kubectl`

### Extra Zsh plugins (non-OMZ)

Enabled via `programs.zsh.plugins`:

- `zsh-autosuggestions`
- `zsh-vi-mode`
- `zsh-syntax-highlighting`
- `fzf-tab`
- `powerlevel10k` (theme)

### Related tools enabled

- `programs.fzf.enable = true`
- `programs.direnv.enable = true`
- `programs.direnv.nix-direnv.enable = true`
- `programs.zoxide` (initialized last, as `cd`), `programs.atuin`
- Custom Zsh helpers `hms()` / `hms-fast()` wrap `home-manager switch --flake .#<target> --impure` (with optional `--no-build-output`), auto-`cd` to the repo root via `git rev-parse`, accept a flake target like `hms k3s`, and default to `hosts/$(hostname -s).nix` when it exists (else `current`).

### Where to edit

All of the above lives in `modules/core/shell.nix`; component-specific snippets (navi widget, micromamba
hook) live in their component.

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
