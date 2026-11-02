## Image and desktop

This image is built on `ghcr.io/ublue-os/bluefin-dx` at `image-version: 44`, the current stable Bluefin DX stream (Fedora 44). Basing on the DX image keeps its developer and virtualization tooling — Podman, Docker, Distrobox, Incus, libvirt/QEMU, the `ujust` recipe collection and the rest of the DX package set — and layers a Hyprland desktop on top.

Only the **GDM display manager** is removed. The GNOME packages themselves stay installed, because they are part of the dependency graph the DX tooling is built on; removing the whole stack risks taking DX components with it. GNOME therefore remains present as an inert fallback session, but nothing selects it — the system boots to SDDM with **Hyprland** preselected.

Everything the desktop needs is baked into the image at build time. There is no Nix, no Home Manager and no `curl | sh` step for the user to run: this is an rpm-ostree Fedora image, and all desktop packages come from Fedora repos or the `lionheartp/Hyprland` COPR.

## Hyprland desktop

The desktop is assembled from RPMs only:

- **Hyprland** itself (with its own `/usr/share/wayland-sessions` entry), plus `quickshell`, `xdg-desktop-portal-hyprland`, `hyprpolkitagent` and `xdg-desktop-portal-gtk`
- **SDDM** as the greeter, configured for the X11 display server and preseeded to select Hyprland by `sddm-default-session.service`
- **Ambxst 1.3.14** as the desktop shell, installed at build time from its pinned upstream release into `/usr/share/ambxst` (plus `/usr/libexec/ambxst/ambxst` and an `/usr/bin/ambxst` wrapper that sets `AMBXST_SHELL`). Ambxst's own `install.sh` refuses to run as root, so the image ships `config/files/usr/libexec/hyperblue/install-ambxst` instead, which verifies pinned checksums.
- A deliberately small app set: Alacritty, Ptyxis (Bluefin's container-oriented terminal), Thunar, `pavucontrol`, `nm-connection-editor`, Blueman, GNOME Keyring, and the fonts/tools Ambxst's Fedora dependency list expects.

System-wide defaults live in `/etc/xdg/hypr/hyprland.conf`; a personal `~/.config/hypr/hyprland.conf` takes precedence once Ambxst has written one. Fallback shortcuts: Super+Enter (terminal), Super+D (launcher), Super+E (file manager), Super+Q (close), Super+Shift+E (exit).

On first login the session helper runs `ambxst install hyprland`, which sources `~/.local/share/ambxst/hyprland.conf` from your Hyprland config. It then appends the `exec-once` lines that start the polkit agent and the Hyprland portal, so those keep working after Ambxst rewrites your config.

## The `hyperblue` command

`/usr/bin/hyperblue` is the one resident script in the image. It exists only for per-user work that cannot be done at build time — everything else is already installed.

```bash
hyperblue setup     # run pending first-run setup steps (once per user)
hyperblue update    # re-run steps after the image was updated or rebased
hyperblue fix       # re-run steps even if they are recorded as done
hyperblue status    # image version, setup state and per-step results
hyperblue version   # image and CLI version
```

Options for `setup`/`update`/`fix`: `--list`, `--only STEP`, `--force`, `--no-wait`, `--auto`.

`hyperblue setup` runs automatically once per user on first login through `hyperblue-setup.service`. It waits for network connectivity before starting (with a timeout, and `systemd` retries on failure), records each step under `$XDG_STATE_HOME/hyperblue`, and is safe to re-run. To re-run it by hand:

```bash
ujust re-run-hyperblue-setup
ujust hyperblue-status
```

**It does not initialize Waydroid** — that stays an explicit, user-invoked step (see below), because it downloads a large Android image and picks hardware-specific options.

## Waydroid

Waydroid is supported through Bluefin's own integration, which this image keeps intact. The Fedora 44 `kernel-core` used by the DX base builds Binder in rather than as a module — `CONFIG_ANDROID_BINDER_IPC=y`, `CONFIG_ANDROID_BINDERFS=y`, `CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"` — so no custom kernel or akmod is needed and none is installed.

Initialize it once, after your first login, with internet available:

```bash
ujust setup-waydroid init
```

`ujust setup-waydroid` also offers `configure` (Android image tweaks via the upstream `waydroid_script` helper), `gpu`, `integration` (multi-window mode) and `reset`. `ujust configure-waydroid` is an alias for the same recipe.

Two image-specific details are handled for you: `waydroid-workaround.service` bind-mounts `/usr/lib/waydroid` so the read-only `/usr` does not break the container, and the `init` recipe relabels `/var/lib/waydroid` with `restorecon` so SELinux does not block it on Fedora.

## Installation

Rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```bash
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/therosin/hyperblue:latest
  ```
- Reboot to complete the rebase:
  ```bash
  systemctl reboot
  ```
- Then rebase to the signed image:
  ```bash
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/therosin/hyperblue:latest
  ```
- Reboot again to complete the installation:
  ```bash
  systemctl reboot
  ```

The `latest` tag points to the latest image build. The build remains on Fedora 44 until `image-version` in `recipes/recipe.yml` is deliberately changed.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running:

```bash
cosign verify --key cosign.pub ghcr.io/therosin/hyperblue
```
