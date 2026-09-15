# frozen_string_literal: true

# gem 入口（RubyGems 命名惯例：require "citrine-native-libui"）。
#
# libui 后端 = libui 控件适配层（Widgets::Libui）+ uiDrawContext 绘制
# （Libui::Painter）+ 真控件冒烟/验收工具。核心（Renderer/App/StyleMatrix）
# 来自 citrine-native。
#
# 加载本 gem 即登记后端 :libui 并把它设为默认——
#   require "citrine-native-libui"
#   Citrine::Native.run(Counter, title: "计数器")   # 不用传 backend:
require "citrine-native"

module Citrine
  module Native
    register_backend(:libui, widgets: "Citrine::Native::Widgets::Libui")
    self.default_backend = :libui
  end
end

require_relative "citrine/native/libui/version"
require_relative "citrine/native/libui/painter"
require_relative "citrine/native/widgets/libui"
