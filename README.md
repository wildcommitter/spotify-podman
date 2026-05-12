# Spotify in Podman (Wayland + PipeWire)

Run the official Spotify Linux client inside a rootless Podman container, with native Wayland display and PipeWire audio passthrough. Tested on CachyOS; should work on any modern Linux distro with Wayland and PipeWire.

## Why?

Sandboxing the proprietary Spotify client from the rest of your system, without giving up native graphics or audio performance. Compared to the Flatpak or Snap versions, this gives you full control over the container image and dependencies.

## Requirements

- Linux with a Wayland compositor (GNOME, KDE Plasma, Hyprland, Sway, etc.)
- PipeWire as the audio server (with or without `pipewire-pulse`)
- [Podman](https://podman.io/) 4.0 or newer
- AMD, Intel, or NVIDIA GPU with working `/dev/dri` access
- ~500 MB of disk space for the container image

## Installation

Clone or download this repository, then from inside the directory:

```bash
chmod +x install.sh
./install.sh
```

The installer will:

1. Verify Podman is installed and the source files are present
2. Validate the desktop entry syntax
3. Build the container image (tag: `spotify`)
4. Install the launcher script to `~/.local/bin/spotify-podman`
5. Install the desktop entry to `~/.local/share/applications/`
6. Refresh the desktop database so the app appears in your menu

No root privileges are required — everything stays under `$HOME`.

## Usage

Launch Spotify from your application menu, or from a terminal:

```bash
spotify-podman
```

The container is single-instance and runs detached. Spotify URIs (`spotify:track:...`, `spotify:playlist:...`) will open in the container if you set it as the default handler:

```bash
xdg-mime default spotify-podman.desktop x-scheme-handler/spotify
```

To stop Spotify, close the window normally or run:

```bash
podman stop spotify
```

The "Quit Spotify" right-click action in the application menu does the same thing.

## How it works

The setup has four pieces:

**`Containerfile`** — Builds a Debian trixie image with the Spotify client and all required runtime libraries (Wayland client libs, Mesa userspace drivers, PipeWire client, libpulse shim, fonts, D-Bus). Includes a `spotify-wayland` wrapper that launches Spotify with the correct Ozone/Wayland flags.

**`spotify-podman`** — Host-side launcher script. Auto-detects the active Wayland socket, builds the correct `podman run` invocation, and logs each launch to `~/.local/state/spotify-podman/launch.log` for debugging.

**`spotify-podman.desktop`** — Desktop entry for application menus, with a Quit action and `spotify:` URI handling.

**`install.sh`** — Installer that ties it all together, rewriting paths to absolutes during install so the menu entry works regardless of `$PATH`.

### What gets forwarded into the container

| Resource | Host path | Purpose |
|----------|-----------|---------|
| Wayland socket | `$XDG_RUNTIME_DIR/wayland-N` | Display |
| PipeWire socket | `$XDG_RUNTIME_DIR/pipewire-0` | Audio |
| D-Bus session bus | `$XDG_RUNTIME_DIR/bus` | MPRIS / media keys |
| GPU device | `/dev/dri` | Hardware acceleration |

User configuration and cache persist across runs via two named volumes (`spotify-config`, `spotify-cache`).

## Troubleshooting

### Window doesn't appear when launching from the menu

Check the launch log:

```bash
cat ~/.local/state/spotify-podman/launch.log
```

The most common cause is a stale Spotify process holding the single-instance lock. Clear it:

```bash
pkill -9 -f spotify
podman rm -f spotify
```

### Audio doesn't work

Verify your host is actually running PipeWire and the socket exists:

```bash
pipewire --version
ls -la $XDG_RUNTIME_DIR/pipewire-0
```

If the socket is missing, make sure PipeWire is running:

```bash
systemctl --user status pipewire
```

### GPG key error during build

Spotify rotates their apt signing key every few months. If `podman build` fails with `NO_PUBKEY XXXXXXXXXXXXXXXX`, edit the `Containerfile` and replace the existing hex key ID with the one from the error, then rebuild:

```bash
podman build -t spotify .
```

### glibc version mismatch

If apt reports `spotify-client : Depends: libc6 (>= 2.XX)` and the base image is too old, bump the `FROM` line in the `Containerfile` to the next Debian release (e.g. `debian:trixie` → `debian:forky` when it lands).

### Updating Spotify itself

The apt layer is cached. Force a rebuild from scratch to pull the latest version:

```bash
podman build --no-cache -t spotify .
```

## Uninstalling

```bash
rm -f ~/.local/bin/spotify-podman
rm -f ~/.local/share/applications/spotify-podman.desktop
rm -rf ~/.local/state/spotify-podman
podman image rm spotify
podman volume rm spotify-config spotify-cache  # also wipes your Spotify login
```

The last command is optional — keeping the volumes preserves your login state and cached data for next time.

## File layout

```
.
├── Containerfile              # Builds the spotify image
├── spotify-podman             # Host launcher script
├── spotify-podman.desktop     # Desktop entry
├── install.sh                 # Installer
└── README.md                  # This file
```

## License

The build files in this repository are provided as-is. The Spotify client itself is proprietary software distributed under [Spotify's terms of use](https://www.spotify.com/legal/end-user-agreement/).
