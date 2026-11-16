# TAIA setup

TAIA sets up your personal AI assistant on your own computer. This page is where you download the setup app. You need the license key you received from The Mullings Group.

Download the latest version from the **Releases** page of this repository (on the right of this page), or follow the steps for your computer below.

## Windows

1. Open the **Releases** page and download `taia-setup-win-x64.exe`.
2. Double-click the file.
3. Windows may show **"Windows protected your PC"**. This appears because the app is new, not because something is wrong.
   1. Click **More info**.
   2. Click **Run anyway**.
4. Follow the steps in the setup page that opens in your browser.

## Mac (Apple silicon: M1 or newer)

1. Open the **Terminal** app (press Cmd+Space, type `Terminal`, press Return).
2. Copy this line, paste it into Terminal and press Return:

```
curl -sL https://raw.githubusercontent.com/TheMullingsLabs/taia-dist/main/install.sh | bash
```

3. Open a new Terminal window, then type this and press Return:

```
taia-setup
```

4. Follow the steps in the setup page that opens in your browser.

Intel Macs are not supported yet. Contact The Mullings Group if you have one.

## Linux and WSL (Windows Subsystem for Linux)

Needs Ubuntu 22.04 or newer (or another 64-bit Linux from 2022 or later).

1. Open a terminal.
2. Run:

```
curl -sL https://raw.githubusercontent.com/TheMullingsLabs/taia-dist/main/install.sh | bash
```

3. Open a new terminal, then run:

```
taia-setup
```

## Check a download yourself (optional)

Each release has a `checksums-<target>.txt` file. It holds the SHA-256 checksum of the matching app. The Mac and Linux installer checks it for you, and refuses a file that doesn't match.

## Help

Contact The Mullings Group: support@themullingsgroup.com

---

*For TMG: this README and `install.sh` are copied from `dist/` in the private `taia` repo, which is their source of truth. Edit them there, not here.*
