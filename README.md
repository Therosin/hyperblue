## Image and desktop

This image is built on `ghcr.io/ublue-os/bluefin-dx` at `image-version: 44`, the current stable Bluefin DX stream (Fedora 44). Basing on the DX image keeps its developer and virtualization tooling — Podman, Docker, Distrobox, Incus, libvirt/QEMU, the `ujust` recipe collection and the rest of the DX package set — and layers a Hyprland desktop on top.

Only the **GDM display manager** is removed. The GNOME packages themselves stay installed, because they are part of the dependency graph the DX tooling is built on; removing the whole stack risks taking DX components with it. GNOME therefore remains present as an inert fallback session, but nothing selects it — the system boots to SDDM with **Hyprland** preselected.

Everything the desktop needs is baked into the image at build time. There is no Nix, no Home Manager and no `curl | sh` step for the user to run: this is an rpm-ostree Fedora image, and all desktop packages come from Fedora repos or the `lionheartp/Hyprland` COPR.

## Hyprland desktop

The default system language is English (UK), `en_GB.UTF-8`. The keyboard defaults to UK English in Hyprland (`gb`), the SDDM X11 greeter (`gb`), and the text console (`uk`). Existing personal Hyprland Lua configs keep their keyboard settings; set `input.kb_layout = "gb"` in your `hl.config` block to switch an existing config.

The desktop is assembled from RPMs only:

- **Hyprland** itself (with its own `/usr/share/wayland-sessions` entry), plus `xdg-desktop-portal-hyprland`, `hyprpolkitagent` and `xdg-desktop-portal-gtk`
- **SDDM** as the greeter, configured for the X11 display server and preseeded to select Hyprland by `sddm-default-session.service`
- **Noctalia** as the desktop shell, installed from the `noctalia-git` RPM in `lionheartp/Hyprland`.
- A deliberately small app set: Alacritty, Ptyxis (Bluefin's container-oriented terminal), Thunar, `pavucontrol`, `nm-connection-editor`, Blueman and GNOME Keyring.
- **`lpm`**, Lite XL's plugin manager, at `/usr/bin/lpm`. It is pinned to 1.5.1 and SHA-256 verified by `config/scripts/install-lpm.sh` at build time.

System-wide defaults live in `/etc/xdg/hypr/hyprland.lua`. On first setup they are copied to `$XDG_CONFIG_HOME/hypr/hyprland.lua` (default `~/.config/hypr/hyprland.lua`) if no personal Lua config exists. Shortcuts: Super+Enter (terminal), Super+D (Noctalia launcher), Super+E (file manager), Super+Q (close), Super+Shift+E (exit). The defaults also start the polkit agent and Hyprland portal.

The offline setup step adds the following [documented Noctalia startup hook](https://docs.noctalia.dev/noctalia/v5.4.1/compositor-settings/hyprland/) to an existing Lua config without replacing personal settings. Repeated setup runs do not duplicate the hook.

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd("noctalia")
end)
```

After updating an existing installation, run `hyperblue update` and log out and back in. Personal legacy `hyprland.conf` files are preserved; port any custom settings you want to keep to `hyprland.lua`.

## The `hyperblue` command

`/usr/bin/hyperblue` is the one resident script in the image. It exists only for per-user work that cannot be done at build time — everything else is already installed.

```bash
hyperblue setup     # run pending first-run setup steps (once per user)
hyperblue update    # re-run steps after the image was updated or rebased
hyperblue fix       # re-run steps even if they are recorded as done
hyperblue install   # install per-user developer tools into ~/.local
hyperblue status    # image version, setup state and per-step results
hyperblue version   # image and CLI version
```

Options for `setup`/`update`/`fix`: `--list`, `--only STEP`, `--force`, `--no-wait`, `--auto`.

`hyperblue install [NAME...]` puts tools in `~/.local/bin`, which login shells already have on `PATH`. With no name it installs all of them; a tool that is already present is skipped, so it is safe to re-run.

| Tool | What lands where |
| --- | --- |
| `lite-xl` | Lite XL `2.1.8` in `~/.local/share/lite-xl` (binary plus `data/`), symlinked to `~/.local/bin/lite-xl`. Registered with `lpm`, so `lpm install <plugin>` targets this copy. |
| `uv` | `uv` and `uvx` in `~/.local/bin` |
| `bun` | `bun` in `~/.local/bin` |
| `deno` | `deno` in `~/.local/bin` |
| `fnm` | `fnm` in `~/.local/bin` |
| `pyenv` | pyenv `2.8.14` plus pyenv-virtualenv in `~/.local/share/pyenv`, with `~/.local/bin/pyenv` as the entry point |
| `luaver` | `luaver` 1.1.0 in `~/.local/share/luaver`, a `~/.local/bin/luaver` shim that sources it |

Every download is pinned to a version and verified against a SHA-256 where upstream publishes one (`lpm`, `luaver`). `lite-xl` resolves the current release at install time rather than hard-coding a version.

`--list` prints the available names. `lpm` itself ships in the image (`/usr/bin/lpm`), pinned and checksum-verified at build time, so plugin installs work without a separate download.

`hyperblue setup` runs automatically on login through `hyperblue-setup.service`, records each step under `$XDG_STATE_HOME/hyperblue`, and is safe to re-run. Newly added steps run even if an earlier image's setup completed. Only steps that declare a network requirement wait for connectivity; Noctalia integration runs offline. To re-run it by hand:

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

## Local development

The `Justfile` wraps BlueBuild the same way `.github/workflows/build.yml` does, so a local build goes through the identical recipe. Requires `just`, `podman` and the `bluebuild` CLI; the VM steps additionally need `bootc-image-builder` (via `sudo`) and `systemd-vmspawn`.

| Recipe | What it does |
| --- | --- |
| `just validate` | Check `recipes/recipe.yml` without building |
| `just generate` | Render the Containerfile BlueBuild would build |
| `just build` | Build `localhost/hyperblue:latest` with rootless podman |
| `just shell` | Open a shell inside that image |
| `just build-qcow2` / `just build-raw` | Build the image, then a disk image in `output/` |
| `just rebuild-qcow2` / `just rebuild-raw` | Rebuild only the disk image from the current image |
| `just spawn-vm` | Boot `output/qcow2/disk.qcow2` with `systemd-vmspawn` |
| `just run-vm-qcow2` / `just run-vm-raw` | Boot the disk image in `qemux/qemu` with a browser console |
| `just check` / `just fix` | Lint or format the Justfile and shell scripts |
| `just clean` | Remove build artefacts, `output/` and the local image |

`just spawn-vm` takes `rebuild=1` to force a fresh disk image, plus `type`, `ram`, `cpus` and `console` (`just spawn-vm rebuild=1 ram=8G console=native`). Only the disk-image step uses `sudo`, because `bootc-image-builder` needs loop devices; the container build stays rootless.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running:

```bash
cosign verify --key cosign.pub ghcr.io/therosin/hyperblue
```
