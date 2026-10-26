## Code signing policy

Free code signing provided by [SignPath.io](https://signpath.io), certificate by [SignPath Foundation](https://signpath.org).

- **Signed files:** the Windows `Hawwel.exe` and `Hawwel-Setup.exe`, built by GitHub Actions from this repository (see `.github/workflows/windows.yml`). Nothing is signed that wasn't built from this source code.
- **Roles:** Author, Reviewer and Approver: [Ashraf](https://github.com/ashrafabdulmn3m) (maintainer). Contributions from others come as pull requests and are reviewed before merging. Every release is approved manually before it is signed.

## Privacy policy

Hawwel does not collect, store or send any personal data. The text you convert is processed locally on your computer, and the clipboard is only used temporarily and restored right after.

The only network connection is in the **Windows** version: it can check GitHub (`api.github.com`) for a newer release and download it when you press **Update**. This check is on by default and can be turned off with **"Check for updates automatically"** in the Hawwel window (you can still check manually). Nothing is sent except the normal information of an HTTPS request (such as your IP address). The macOS version makes no network connections.
