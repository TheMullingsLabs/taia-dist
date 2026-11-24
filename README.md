# TAIA

TAIA sets up your personal AI assistant on your own computer. The easiest place to get it is **https://gettaia.app/download**. This repository holds the same files. You need the license key you received from The Mullings Group.

Install TAIA once. It puts a **TAIA icon on your desktop** and starts a short guided setup. After that, click the TAIA icon to open your Dashboard. TAIA checks for updates each time it starts and asks before it installs one.

## Windows

1. Download `taia-win-x64.exe` from https://gettaia.app/download (or this repository's **Releases** page).
2. Open the downloaded file.
3. Windows may show **"Windows protected your PC"**. This appears because the app is new, not because something is wrong.
   1. Click **More info**.
   2. Click **Run anyway**.
4. Follow the guided setup. When it's done, the TAIA icon is on your desktop.

## Mac (Apple silicon: M1 or newer)

1. Download **TAIA-mac.zip** from the [latest release](https://github.com/TheMullingsLabs/taia-dist/releases/latest/download/TAIA-mac.zip).
2. Open the downloaded file, then double-click **TAIA**. If your Mac asks whether to open it, click **Open**.
3. Follow the guided setup in the Terminal window that opens. When it's done, the TAIA icon is on your desktop.

Or install from Terminal: open the **Terminal** app (press Cmd+Space, type `Terminal`, press Return), paste this line and press Return:

```
curl -sL https://gettaia.app/install.sh | bash
```

Don't download `taia-darwin-arm64` by hand: it is for the line above and for TAIA's updater, and a Mac opens it as text.

Intel Macs are not supported yet. Contact The Mullings Group if you have one.

## Linux and WSL (Windows Subsystem for Linux)

Needs Ubuntu 22.04 or newer (or another 64-bit Linux from 2022 or later).

1. Open a terminal.
2. Run:

```
curl -sL https://gettaia.app/install.sh | bash
```

3. Follow the guided setup. When it's done, the TAIA icon is on your desktop (on WSL, your Windows desktop).

## Every day

- **Open TAIA:** click the TAIA icon. It starts TAIA if it isn't running and opens your Dashboard in your browser. In a terminal, `taia go` does the same.
- **Stop TAIA:** type `taia stop` in a terminal.
- **Updates:** when a new version is out, your Dashboard shows "TAIA vX is available" with an **Update now** button. You can also type `taia update` in a terminal. TAIA checks the download, backs up your Dashboard, updates it and starts it again. Your inboxes, team, knowledge and journal are never touched.

## Check a download yourself (optional)

Each release has a `checksums-<target>.txt` file. It holds the SHA-256 checksum of the matching app. The Mac and Linux installer and TAIA's own updater check it for you, and refuse a file that doesn't match.

## Help

Contact The Mullings Group: support@themullingsgroup.com

---

*For TMG: this README and `install.sh` are copied from `dist/` in the private `taia` repo, which is their source of truth. Edit them there, not here.*
