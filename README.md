<p align="center">
  <img src="logo.png" width="140" alt="Hawwel logo">
</p>

<h1 align="center">Hawwel | حوّل</h1>

<p align="center">
  Typed in the wrong keyboard language? Select the text, press a shortcut, and it's fixed.<br>
  كتبت بالكيبورد الغلط؟ حدّد الكلام واضغط اختصار، ويتصلّح.
</p>

---

## What it does

Hawwel is a small macOS app that converts text typed with the wrong keyboard layout between **English and Arabic**.

`lvpfh` → `مرحبا`  and  `مرحبا` → `lvpfh`

- Works in any app: browsers, Word, Notes, Photoshop and more.
- No selection? It converts the last word you typed.
- Detects the direction automatically.
- Choose your own shortcut (default: `⌃K`).
- Optional menu bar icon and launch at login.
- Runs fully offline. No data collected, nothing sent anywhere.

## Download

Get the latest `Hawwel.dmg` from the [**Releases page**](https://github.com/ashrafabdulmn3m/Hawwel/releases).

Requires **macOS 14 or later**. Works with the **ABC or US** English layout and any **Arabic** layout (Arabic – PC is preferred).

## Install

1. Open `Hawwel.dmg` and drag **Hawwel** to **Applications**.
2. Open it. macOS will warn that the app is from an unidentified developer, because this version isn't notarized by Apple yet.
3. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
4. If you don't see the button, run this in Terminal and open the app again:
```
   xattr -cr /Applications/Hawwel.app
```
5. In the Hawwel window, click **Enable** and turn Hawwel on under **Privacy & Security → Accessibility**. Then quit and reopen the app.

## Usage

1. Type something with the wrong layout.
2. Select it, or leave nothing selected to fix the last word.
3. Press your shortcut (default `⌃K`).

You can change the shortcut from the Hawwel window.

## Why does it need Accessibility permission?

To copy the selected text and paste the converted text into other apps, Hawwel sends the same keystrokes you would (⌘C and ⌘V). In Adobe apps it types the converted text directly instead. Your clipboard is restored right after.

## Build from source

1. Clone the repo and open `Hawwel.xcodeproj` in Xcode.
2. Select your own signing team under **Signing & Capabilities**.
3. Run with **⌘R**.

Built with SwiftUI and [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).

## Notes

- The Accessibility permission may need to be re-granted after updating the app.
- Found a bug or a layout that doesn't work? [Open an issue](https://github.com/ashrafabdulmn3m/Hawwel/issues).

## License

MIT. See [LICENSE](LICENSE).
