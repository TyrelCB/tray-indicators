# Tray Indicators

Small Ubuntu GNOME tray apps in one repo:

- `resource-usage-tray`: shows `CPU x% | MEM x% : xGB | GPU x%`
- `obs-tray-indicator`: shows OBS state, current scene, and notifications

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/tyrel/tray-indicators/main/install.sh | bash
```

The installer:

- installs required Ubuntu packages
- installs `websocket-client` into `~/.local`
- copies both tray apps into `~/.local/bin`
- installs the OBS tray icons into `~/.local/share/obs-tray-indicator/icons`
- installs the resource tray autostart entry
- installs and starts the OBS tray user service

## Local Install

```bash
./install.sh
```

## Repo Layout

```text
apps/
  obs-tray-indicator/
    icons/
    obs-tray-indicator
    obs-tray-indicator.service
  resource-usage-tray/
    resource-usage-tray
    resource-usage-tray.desktop.in
install.sh
```

## Notes

- Target environment: Ubuntu GNOME with AppIndicators enabled
- System packages are installed with `apt`
- Python-only websocket support is installed with `pip --user`
