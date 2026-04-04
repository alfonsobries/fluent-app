# Changelog

## [1.5.0](https://github.com/alfonsobries/fluent-app/compare/v1.4.1...v1.5.0) (2026-04-04)


### Features

* drop Intel support, simplify to Apple Silicon only ([6650b2c](https://github.com/alfonsobries/fluent-app/commit/6650b2cf670d3c84cf640a7e8d8c3dd2c39b2046))


### Bug Fixes

* use only Apple Silicon DMG for appcast generation ([03a5455](https://github.com/alfonsobries/fluent-app/commit/03a545521eaa12f5f1c3e487f59ac2d98979f97b))
* use printf instead of echo for Sparkle key file ([f95a98f](https://github.com/alfonsobries/fluent-app/commit/f95a98fbd6336a564eaf96f53e59b34e437417f3))

## [1.4.1](https://github.com/alfonsobries/fluent-app/compare/v1.4.0...v1.4.1) (2026-04-04)


### Bug Fixes

* use temp file for Sparkle private key in CI ([56a22ff](https://github.com/alfonsobries/fluent-app/commit/56a22ff1fc338269b5322e631cf214161dc35a64))

## [1.4.0](https://github.com/alfonsobries/fluent-app/compare/v1.3.2...v1.4.0) (2026-04-04)


### Features

* add Sparkle auto-update support ([5a7d087](https://github.com/alfonsobries/fluent-app/commit/5a7d087d064f04ce31444239505a00d717651b1c))
* add Sparkle auto-update support ([d0529fd](https://github.com/alfonsobries/fluent-app/commit/d0529fdda993722d07e6d000b346169ec38ea465))

## [1.3.2](https://github.com/alfonsobries/fluent-app/compare/v1.3.1...v1.3.2) (2026-04-04)


### Bug Fixes

* add --repo flag and actions permission to release-please trigger ([aeb24d6](https://github.com/alfonsobries/fluent-app/commit/aeb24d608d68343e0e012e95617bbdfb3f4f4c6c))
* build both architectures on macos-14 ARM runner ([0cb346a](https://github.com/alfonsobries/fluent-app/commit/0cb346a8d5d0b84bbbcb1a9867a72e1b52415f4a))
* spinner rotation on its own center axis ([f158dbf](https://github.com/alfonsobries/fluent-app/commit/f158dbf68820f4eb658bff8fc5159199b6a77648))

## [1.3.1](https://github.com/alfonsobries/fluent-app/compare/v1.3.0...v1.3.1) (2026-04-04)


### Bug Fixes

* streamline release flow so site links directly to DMGs ([a0fe057](https://github.com/alfonsobries/fluent-app/commit/a0fe05705776eba2ed8183af1c81fd53d7492994))

## [1.3.0](https://github.com/alfonsobries/fluent-app/compare/v1.2.0...v1.3.0) (2026-04-04)


### Features

* add website demo video ([16d9766](https://github.com/alfonsobries/fluent-app/commit/16d976600fe7a459be428e9406871dfc463bfebd))
* harden app for public release ([b55f350](https://github.com/alfonsobries/fluent-app/commit/b55f3500d0027676ea85cbe3afe81550f5cec4ba))
* polish demo site and hud spinner ([dcd8b67](https://github.com/alfonsobries/fluent-app/commit/dcd8b676cd45d105a8faa5aa70034c226e961d87))
* refresh branding and website release flow ([1d216ec](https://github.com/alfonsobries/fluent-app/commit/1d216ecec9ebae3ce3bfd5c197a9e497654e5718))
* simplify website messaging ([9aada90](https://github.com/alfonsobries/fluent-app/commit/9aada9011062ee6d5119e112d7ae518d1682deec))


### Bug Fixes

* make coverage script portable in ci ([03e6c33](https://github.com/alfonsobries/fluent-app/commit/03e6c338315b8e995a332f7c43a870efabfc4734))
* make release workflow dispatchable ([2744be6](https://github.com/alfonsobries/fluent-app/commit/2744be6a43ad2ed76ce6c397d47200926904e718))
* polish release ui and feedback flows ([e05c120](https://github.com/alfonsobries/fluent-app/commit/e05c120d56502f9198c7dbd56b3dbe8ea3a1bed3))
* stabilize coverage checks in ci ([bbd1cb5](https://github.com/alfonsobries/fluent-app/commit/bbd1cb55128370c779af4f7dba9c3d4d747f9b73))

## [1.2.0](https://github.com/alfonsobries/fluent-app/compare/v1.1.0...v1.2.0) (2026-01-25)


### Features

* add reset to defaults button for shortcut actions ([b366e4e](https://github.com/alfonsobries/fluent-app/commit/b366e4e5acf81896cc03e3da4703d5dddfd40e78))
* add reset to defaults button for shortcut actions ([bbe480b](https://github.com/alfonsobries/fluent-app/commit/bbe480b44bbf501c8806a9f76408e26a832d19eb))

## [1.1.0](https://github.com/alfonsobries/fluent-app/compare/v1.0.0...v1.1.0) (2026-01-24)


### Features

* add automatic releases with release-please ([a1e5951](https://github.com/alfonsobries/fluent-app/commit/a1e5951ccc4ba7c85d87799f260a0066c1006702))

## [1.0.0](https://github.com/alfonsobries/fluent-app/releases/tag/v1.0.0) (2024-01-01)

### Features

* Initial release of Fluent App
* macOS menu bar application for AI-powered text processing
* Support for multiple AI providers (OpenAI, Anthropic, Google, xAI)
* Global hotkey support
* Accessibility integration
