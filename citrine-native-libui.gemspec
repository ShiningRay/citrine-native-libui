# frozen_string_literal: true

require_relative "lib/citrine/native/libui/version"

Gem::Specification.new do |spec|
  spec.name = "citrine-native-libui"
  spec.version = Citrine::Native::Libui::VERSION
  spec.authors = ["ShiningRay"]
  spec.email = ["tsowly@hotmail.com"]

  spec.summary = "libui native runtime for Citrine components"
  spec.description = "citrine-native-libui：Citrine 组件的 libui 原生后端。" \
                     "实现 Citrine::Native 的 Widgets::Base 协议（citrine-native gem），" \
                     "Windows / macOS 上渲染原生控件与自绘面板（area）。"
  spec.homepage = "https://github.com/ShiningRay/citrine-native-libui"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("lib/**/*.rb") + Dir.glob("docs/**/*.md") +
               %w[README.md CHANGELOG.md GOALS.md RELEASING.md LICENSE]
  spec.require_paths = ["lib"]

  # 核心协议与框架件（Renderer/App/StyleMatrix）在后端无关的 citrine-native 里
  spec.add_dependency "citrine", ">= 0.2"
  spec.add_dependency "citrine-native", "~> 0.2"
  spec.add_dependency "libui", ">= 0.1"

  # 过渡依赖：citrine 0.2.0 的 sourcemap.rb 用了 base64，Ruby ≥ 3.4 起它不再是
  # 默认 gem 而 citrine gemspec 未声明——消费端在 Ruby 4.x 下会 LoadError。
  # 上游修复（citrine gemspec 补声明）发布后移除本行。
  spec.add_dependency "base64", ">= 0.2"
end
