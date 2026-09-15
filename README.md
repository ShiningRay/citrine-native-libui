# citrine-native-libui

Citrine 组件的 **libui 原生后端**：实现 [citrine-native](https://github.com/ShiningRay/citrine-native)
（后端无关核心）的 `Widgets::Base` 协议，Windows / macOS 上渲染真原生控件，
数据密集区用自绘面板（area）。

> 本包由原 `citrine-native` 仓库拆分而来（2026-09-16，架构见 [GOALS.md](GOALS.md)）；
> rubygems.org 上的旧 `citrine-native 0.1.0` 是拆分前的 monolith，保留不更新。

```ruby
require "citrine-native-libui"   # 加载即登记后端 :libui 并设为默认

Citrine::Native.run(Counter, title: "计数器", width: 400, height: 300)
```

## 能力与已知限制

- ✅ 原生控件（stack/row/label/button/text_input/check_box）、自绘面板（area：
  矩形/折线/多边形/富文本/度量/裁剪）、受控输入、定时器、窗口激活（macOS）
- ⚠️ **原生控件不可着色**（libui 不暴露外观 API）——深色主题只覆盖 area 自绘部分；
  需要控件级样式请看 [citrine-native-gtk](https://github.com/ShiningRay/citrine-native-gtk)
  （GTK3 后端，原生支持 CSS）
- ⚠️ entry 不暴露按键事件（`on_enter` 不可用）；Windows 的 focus / 窗口最小尺寸如实降级

能力差异总表见 [docs/design/platform-matrix.md](docs/design/platform-matrix.md) 与
[docs/design/style-matrix.md](docs/design/style-matrix.md)。

## 开发

```bash
bundle install          # 需同级目录有 citrine / citrine-native 两仓
rake test               # 桩测 + 真控件冒烟（不开窗）
rake gui_smoke          # 真窗口冒烟
rake demo_acceptance    # 两个 demo 的真窗口端到端（仅 Windows）
rake consumer_smoke     # 三 gem 打包 → 干净 GEM_HOME → 仓库外渲染
```
