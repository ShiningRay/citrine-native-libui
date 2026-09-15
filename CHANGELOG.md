# CHANGELOG

## [0.1.0] - 2026-09-16

### Added

- 首个以 `citrine-native-libui` 名义发布的版本：libui 后端（Widgets::Libui +
  Libui::Painter/TextCache），实现 citrine-native 核心的 Widgets::Base 协议。
- 内容即原 `citrine-native` 0.1.0 monolith 的全部控件代码（2026-09-15 发布，
  保留在 rubygems.org 不更新），拆分见核心包 CHANGELOG 0.2.0。

### Changed

- 依赖线改为 `citrine-native ~> 0.2`（核心）+ `citrine >= 0.2`。
