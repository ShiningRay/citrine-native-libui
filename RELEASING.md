# frozen_string_literal: true

# 发布手册（RELEASING）——citrine-native-libui
#
# 发布走 RubyGems Trusted Publishing（OIDC）：流水线里没有任何 secret。
# 结构与主发布手册（核心包 citrine-native 的 RELEASING.md）一致，差异只有：
#
# 1. **门禁矩阵是 macOS + Windows**（ubuntu 上 libui 起不来——GTK 才有这个问题，
#    libui 是没装 GTK 就直接 LoadError，见核心包无关性说明）。
# 2. **Trusted Publisher 要按本 gem 名单独注册**：
#    rubygems.org → Account settings → Trusted Publishers → Register
#    （owner: ShiningRay，repository: citrine-native-libui，workflow: release.yml，
#    environment: 留空）。核心包 citrine-native 的注册对本 gem 无效。

## 发布步骤

```bash
# 1. 版本与 CHANGELOG 一致（lib/citrine/native/libui/version.rb ↔ CHANGELOG.md）
# 2. 提交并推送 main
# 3. 打标签触发发布（工作流自己校验标签与 VERSION 一致）
git tag v0.1.0 && git push origin v0.1.0
```

工作流四步：gate（macOS + Windows 真跑 `bundle exec rake`）→ 校验标签 →
`gem build` → 附产物到 GitHub Release → OIDC 换凭据 → `gem push`。

## 发布后验证

```bash
gem install citrine-native-libui
ruby -r citrine-native-libui -e 'puts Citrine::Native::Libui::VERSION'
```

## 出错时

- 工作流在"校验标签"或门禁失败：`git push --delete origin v0.1.0` 修好重打
  （没有产物被发布）。
- 已发布到 RubyGems 发现问题：优先发修复版本；确实要撤就 `gem yank`。
