[![GitHub Release](https://img.shields.io/github/v/release/nikstudiovn/XSign?include_prereleases)](https://github.com/nikstudiovn/XSign/releases)
[![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nikstudiovn/XSign/total)](https://github.com/nikstudiovn/XSign/releases)
[![GitHub License](https://img.shields.io/github/license/nikstudiovn/XSign?color=%23C96FAD)](https://github.com/nikstudiovn/XSign/blob/main/LICENSE)

<div align="center">

# XSign

On-device sideloading app for developer certificates.

*XSign is a modified version of [Feather](https://github.com/claration/Feather) by [Samara (claration)](https://github.com/claration), licensed under GPL-3.0.*

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="demo-dark.png"><source media="(prefers-color-scheme: light)" srcset="demo-light.png"><img alt="XSign" src="demo-light.png"></picture></p>

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

## Changes from Feather

- Rebranded as XSign (`com.nikstudiovn.xsign`, URL scheme `xsign://`).
- Server installs always use **Semi Local** mode: the install link opens directly, without the in-app Safari page, the "connection not secure" warning or the "Open in iTunes?" prompt.
- **Fully Local** mode is disabled because the [backloop.dev](https://backloop.dev/) SSL certificate service it relied on was discontinued.

## Download

Visit [releases](https://github.com/nikstudiovn/XSign/releases) and get the latest `.ipa`.

<a href="https://celloserenity.github.io/altdirect/?url=https://raw.githubusercontent.com/nikstudiovn/XSign/refs/heads/main/app-repo.json" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/AltSource_Blue.png?raw=true" alt="Add AltSource" width="200">
</a>
<a href="https://github.com/nikstudiovn/XSign/releases/latest/download/XSign.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Translating

All localizations are located in `Feather/Resources/Localizable.xcstrings`.

To add a new language, open Xcode and use the interface to add/contribute to languages. See the [contributing guide](./CONTRIBUTING.md).

## Acknowledgements

- [Samara](https://github.com/claration) - Original author of [Feather](https://github.com/claration/Feather), which XSign is based on. Consider [sponsoring](https://github.com/sponsors/claration) the original project.
- [idevice](https://github.com/jkcoxson/idevice) - Backend for builds with this included, used for communication with `installd`.
- [Vapor](https://github.com/vapor/vapor) - A server-side Swift HTTP web framework.
- [Zsign](https://github.com/zhlynn/zsign) - Allowing to sign on-device, reimplimented to work on other platforms such as iOS.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) - Fixes/some help
- [Nuke](https://github.com/kean/Nuke) - Image caching.
- [Asspp](https://github.com/Lakr233/Asspp) - Some code for setting up the http server.
- [plistserver](https://github.com/nekohaxx/plistserver) - Hosted on https://api.palera.in, used to serve the install manifest over HTTPS.

## License

This project is licensed under the GPL-3.0 license, the same license as the original Feather project. You can see the full details of the license [here](https://github.com/nikstudiovn/XSign/blob/main/LICENSE).

By contributing to this project, you agree to license your code under the GPL-3.0 license as well (including agreeing to license exceptions), ensuring that your work, like all other contributions, remains freely accessible and open.
