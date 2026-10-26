<p align="center">
  <img src="logo.png" width="140" alt="Hawwel logo">
</p>

<h1 align="center">Hawwel | حوّل</h1>

<p align="center">
  Typed in the wrong keyboard language? Select the text, press a shortcut, and it's fixed.<br>
  كتبت بالكيبورد الغلط؟ حدّد الكلام واضغط اختصار، ويتصلّح.
</p>

<p align="center">
  <a href="https://github.com/ashrafabdulmn3m/Hawwel/releases/download/win-win-v1.0.2/Hawwel-Setup.exe"><b>⬇️ Download Hawwel Windows</b></a>
  &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="https://github.com/ashrafabdulmn3m/Hawwel/releases/download/v1.1.0/Hawwel-1.1.dmg"><b>⬇️ Download Hawwel MacOS</b></a>
</p>

---

## What it does

Hawwel is a small app for **macOS and Windows** that converts text typed with the wrong keyboard layout between **English and Arabic**.

`lvpfh` → `مرحبا`  and  `مرحبا` → `lvpfh`

- Works in any app: browsers, Word, Notes, Photoshop and more.
- No selection? It converts the last word you typed.
- Detects the direction automatically.
- Choose your own shortcut (default: `⌃K` on Mac, `Ctrl + Alt + K` on Windows).
- Optional menu bar / system tray icon and launch at login.
- Runs fully offline. No data collected, nothing sent anywhere.

## Download

| Platform | Download | Requirements |
|---|---|---|
| **Windows** | [**Download Hawwel Windows**](https://github.com/ashrafabdulmn3m/Hawwel/releases/download/win-v1.0.2/Hawwel-Setup.exe) (`Hawwel-Setup.exe`) | Windows 10 or 11, 64-bit |
| **macOS** | [**Download Hawwel MacOS**](https://github.com/ashrafabdulmn3m/Hawwel/releases/download/v1.1.0/Hawwel-1.1.dmg) (`Hawwel-1.1.dmg`) | macOS 14 or later |

Older versions and release notes are on the [Releases page](https://github.com/ashrafabdulmn3m/Hawwel/releases).

Keyboards: on **macOS** it works with the **ABC or US** English layout and any **Arabic** layout (Arabic – PC is preferred). On **Windows** you need **English (US)** and any **Arabic** keyboard added in *Settings → Time & language → Language & region*.

---

## Install on Windows

1. Download [`Hawwel-Setup.exe`](https://github.com/ashrafabdulmn3m/Hawwel/releases/download/win-v1.0.2/Hawwel-Setup.exe) and run it.
2. Windows may show **"Windows protected your PC"**, because the installer isn't code-signed yet. Click **More info**, then **Run anyway**.
3. Click **Next** until **Install**. Leave **Launch Hawwel** checked, and choose whether it should start with Windows.
4. Hawwel runs in the **system tray** (the `^` arrow next to the clock). Click its icon to open the window and change the shortcut.
5. No special permission is needed on Windows.

To remove it: **Settings → Apps → Installed apps → Hawwel → Uninstall**.

## Install on macOS

1. Open `Hawwel-1.1.dmg` and drag **Hawwel** to **Applications**.
2. Open it. macOS will warn that the app is from an unidentified developer, because this version isn't notarized by Apple yet.
3. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
4. If you don't see the button, run this in Terminal and open the app again:
```
   xattr -cr /Applications/Hawwel.app
```
5. In the Hawwel window, click **Enable** and turn Hawwel on under **Privacy & Security → Accessibility**. Then quit and reopen the app.

---

## Usage

1. Type something with the wrong layout.
2. Select it, or leave nothing selected to fix the last word.
3. Press your shortcut (default `⌃K` on Mac, `Ctrl + Alt + K` on Windows).

You can change the shortcut from the Hawwel window.

## Why does it need Accessibility permission? (macOS)

To copy the selected text and paste the converted text into other apps, Hawwel sends the same keystrokes you would (⌘C and ⌘V). In Adobe apps it types the converted text directly instead. Your clipboard is restored right after.

On Windows it works the same way (Ctrl+C and Ctrl+V), but Windows doesn't ask for any permission.

## Build from source

**macOS**

1. Clone the repo and open `HawwelMacOS/Hawwel.xcodeproj` in Xcode.
2. Select your own signing team under **Signing & Capabilities**.
3. Run with **⌘R**.

Built with SwiftUI and [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).

**Windows**

1. Install the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).
2. In the `HawwelWin` folder, run `dotnet run`.

Built with C# and WPF. The installer is built by GitHub Actions (see `.github/workflows/windows.yml`).

## Notes

- The Accessibility permission on macOS may need to be re-granted after updating the app.
- On Windows, Hawwel doesn't work inside apps running **as Administrator**, or inside **Terminal / CMD / PowerShell** (Ctrl+C there stops the running program instead of copying).
- Found a bug or a layout that doesn't work? [Open an issue](https://github.com/ashrafabdulmn3m/Hawwel/issues).

## License

MIT. See [LICENSE](LICENSE).
