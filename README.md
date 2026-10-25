# SEUsign

[![GitHub Release](https://img.shields.io/github/v/release/uxp70/SEUsign?include_prereleases)](https://github.com/uxp70/SEUsign/releases)
[![GitHub License](https://img.shields.io/github/license/uxp70/SEUsign?color=%23C96FAD)](https://github.com/uxp70/SEUsign/blob/main/LICENSE)

<div align="center">

<img title="SEUsign" alt="SEUsign" height="180" src=".github/landing.png">

Sideloading app meant for developer certificates. A fork of [Feather](https://github.com/claration/Feather) by Samara, rebranded as **SEUsign**.

</div>

## Features

- User friendly, and clean UI.
- Sign and install applications.
- Supports [AltStore](https://faq.altstore.io/distribute-your-apps/make-a-source#apps) repositories.
- View detailed information about apps and your certificates.
- Configurable signing options mainly for modifying the app, such as appearance and allowing support for the files app.
  - This includes patching apps for compatibility and Liquid Glass.
- Tweak support for advanced users, using [Ellekit](https://github.com/tealbathingsuit/ellekit) for injection.
  - Supports injecting `.deb` and `.dylib` files.
- No tracking or analytics, ensuring user privacy.
- Open source and free.

## Download

Visit [releases](https://github.com/uxp70/SEUsign/releases) and get the latest `.ipa`.

<a href="https://github.com/uxp70/SEUsign/releases/latest/download/SEUsign.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Building

SEUsign is an iOS app built with Xcode. To build it yourself:

1. Clone the repository (including submodules):
   ```
   git clone --recurse-submodules https://github.com/uxp70/SEUsign.git
   ```
2. Open `SEUsign.xcworkspace` in Xcode.
3. Select the `SEUsign` scheme and build for your device.

Alternatively, the GitHub Actions workflow (`.github/workflows/release.yml`) builds on a macOS runner and produces `packages/SEUsign.ipa`. Trigger it manually from the Actions tab or by pushing a `v*` tag.

## Translating

SEUsign has translation support. All localizations are located in `SEUsign/Resources/Localizable.xcstrings`.

To add a new language, open Xcode and use the interface to add/contribute to languages.

## Acknowledgements

- [Samara (claration)](https://github.com/claration) - Original author of Feather
- [idevice](https://github.com/jkcoxson/idevice) - Backend for builds, used for communication with `installd`.
- [*.backloop.dev](https://backloop.dev/) - localhost with public CA signed SSL certificate
- [Vapor](https://github.com/vapor/vapor) - A server-side Swift HTTP web framework.
- [Zsign](https://github.com/zhlynn/zsign) - Allowing to sign on-device, reimplemented to work on other platforms such as iOS.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) - Fixes/some help
- [Nuke](https://github.com/kean/Nuke) - Image caching.
- [Asspp](https://github.com/Lakr233/Asspp) - Some code for setting up the http server.
- [plistserver](https://github.com/nekohaxx/plistserver) - Hosted on https://api.palera.in.

## License

This project is licensed under the GPL-3.0 license. See [LICENSE](LICENSE) for details.
