# frozen_string_literal: true

# libui 后端的真绘制实现：uiDrawContext 上的图元落地 + 文本布局缓存。
# 图元签名/参数归一/提醒收集来自核心的 Citrine::Native::Painter::Primitives
# （citrine-native gem），这里只做平台调用。
require "libui"

module Citrine
  module Native
    module Libui
      class Painter
        # 核心协议（参数归一 + emit_* 钩子签名）
        include ::Citrine::Native::Painter::Primitives

        attr_reader :width, :height

        # @param ctx   [Fiddle::Pointer] uiDrawContext（只在本次 Draw 回调内有效）
        # @param cache [TextCache] 文本布局缓存：跨帧复用，由适配层按面板持有（随面板销毁 clear!）
        # @param clip  [Array, nil] 当前可见区 [x, y, w, h]（内容坐标；nil = 整块面板可见）
        def initialize(ctx:, width:, height:, cache:, clip: nil)
          @ctx = ctx
          @width = width.to_f
          @height = height.to_f
          @cache = cache
          @clip = clip || [0.0, 0.0, @width, @height]
          @brush = ::LibUI::FFI::DrawBrush.malloc
          @brush.Type = ::LibUI::DrawBrushTypeSolid
          @stroke = ::LibUI::FFI::DrawStrokeParams.malloc
          @stroke.Cap = ::LibUI::DrawLineCapFlat
          @stroke.Join = ::LibUI::DrawLineJoinMiter
          @stroke.MiterLimit = ::LibUI::DrawDefaultMiterLimit
        end

        private

        # ── 平台实现：真 libui 调用 ──────────────────────────────
        # 路径（uiDrawPath）是"一次性"对象：画完立刻 uiDrawFreePath，不能跨图元复用
        # （libui 没有 reset API，且路径不归 Ruby GC 管——漏 free 就是每帧漏一段 C 内存）。

        def emit_rect(x, y, w, h, fill, stroke, line_width, radius)
          with_path do |path|
            if radius.positive?
              round_rect(path, x, y, w, h, radius)
            else
              ::LibUI.draw_path_add_rectangle(path, x, y, w, h)
            end
            ::LibUI.draw_path_end(path)
            fill_path(path, fill)
            stroke_path(path, stroke, line_width)
          end
        end

        def emit_line(x1, y1, x2, y2, color, width)
          with_path do |path|
            ::LibUI.draw_path_new_figure(path, x1, y1)
            ::LibUI.draw_path_line_to(path, x2, y2)
            ::LibUI.draw_path_end(path)
            stroke_path(path, color, width)
          end
        end

        def emit_polyline(points, color, width)
          with_path do |path|
            trace(path, points)
            ::LibUI.draw_path_end(path)
            stroke_path(path, color, width)
          end
        end

        def emit_polygon(points, fill, stroke, line_width)
          with_path do |path|
            trace(path, points)
            ::LibUI.draw_path_close_figure(path)
            ::LibUI.draw_path_end(path)
            fill_path(path, fill)
            stroke_path(path, stroke, line_width)
          end
        end

        def emit_text(entry, x, y)
          # (x, y) 是整段文本外接矩形的**左上角**（libui 的语义），不是基线
          ::LibUI.draw_text(@ctx, entry.layout, x, y)
          self
        end

        def emit_clip_begin(x, y, w, h)
          ::LibUI.draw_save(@ctx)
          with_path do |path|
            ::LibUI.draw_path_add_rectangle(path, x, y, w, h)
            ::LibUI.draw_path_end(path)
            ::LibUI.draw_clip(@ctx, path)
          end
        end

        def emit_clip_end
          ::LibUI.draw_restore(@ctx)
          self
        end

        def text_entry(text, size:, weight:, family:, color:, wrap_width:, align:)
          @cache.entry(string: text, size: size, weight: weight, family: family, color: color,
                       wrap_width: wrap_width, align: align)
        end

        def with_path
          path = ::LibUI.draw_new_path(::LibUI::DrawFillModeWinding)
          begin
            yield path
          ensure
            ::LibUI.draw_free_path(path)
          end
          self
        end

        def trace(path, points)
          points.each_with_index do |(x, y), index|
            index.zero? ? ::LibUI.draw_path_new_figure(path, x, y)
                        : ::LibUI.draw_path_line_to(path, x, y)
          end
        end

        # 圆角矩形：四角各一段 90° 圆弧（y 轴向下，角度从 +x 往 +y 增长即顺时针）
        def round_rect(path, x, y, w, h, radius)
          half_pi = Math::PI / 2
          ::LibUI.draw_path_new_figure_with_arc(path, x + radius, y + radius, radius, Math::PI, half_pi, 0)
          ::LibUI.draw_path_line_to(path, x + w - radius, y)
          ::LibUI.draw_path_arc_to(path, x + w - radius, y + radius, radius, -half_pi, half_pi, 0)
          ::LibUI.draw_path_line_to(path, x + w, y + h - radius)
          ::LibUI.draw_path_arc_to(path, x + w - radius, y + h - radius, radius, 0.0, half_pi, 0)
          ::LibUI.draw_path_line_to(path, x + radius, y + h)
          ::LibUI.draw_path_arc_to(path, x + radius, y + h - radius, radius, half_pi, half_pi, 0)
          ::LibUI.draw_path_close_figure(path)
        end

        def fill_path(path, color)
          return if color.nil?

          @brush.R = color[0]
          @brush.G = color[1]
          @brush.B = color[2]
          @brush.A = color[3]
          ::LibUI.draw_fill(@ctx, path, @brush)
        end

        def stroke_path(path, color, width)
          return if color.nil? || width <= 0

          @brush.R = color[0]
          @brush.G = color[1]
          @brush.B = color[2]
          @brush.A = color[3]
          @stroke.Thickness = width
          ::LibUI.draw_stroke(@ctx, path, @brush, @stroke)
        end

        # 文本布局缓存（每个面板一份，见类注释）。面板销毁时必须 clear!。
        #
        # 键除设计里写的 (string, size, weight, family) 还带上 color / wrap_width / align：
        # 颜色是烘进 attributed string 的属性（涨跌红绿靠它），宽度与对齐决定换行与外接
        # 矩形——少任何一项，缓存命中都会拿到"另一段文本"的布局。
        class TextCache
          ALIGN_CODES = { left: :DrawTextAlignLeft, center: :DrawTextAlignCenter,
                          right: :DrawTextAlignRight }.freeze

          def initialize
            @entries = {}
            @fonts = {}
          end

          # 取（或建）一条布局缓存
          def entry(string:, size:, weight:, family:, color:, wrap_width:, align:)
            @entries[[string, size, weight, family, color, wrap_width, align]] ||=
              build(string, size, weight, family, color, wrap_width, align)
          end

          # 释放全部 libui 对象（顺序：layout → 它引用的 attributed string / 字体描述符）
          def clear!
            @entries.each_value do |cached|
              ::LibUI.draw_free_text_layout(cached.layout)
              ::LibUI.free_attributed_string(cached.attr_string)
            end
            @entries.clear
            @fonts.each_value do |font|
              # 只有 uiLoadControlFont 填过的描述符能交给 uiFreeFontDescriptor；
              # 自建 family 的（Family 指向我们自己的 buffer）交给它会被 free 掉
              # 不该 free 的内存——实测直接 abort 进程（GOALS 变更日志 NA-1）
              ::LibUI.free_font_descriptor(font[:descriptor]) if font[:libui_owned]
            end
            @fonts.clear
            self
          end

          # 缓存条目数（测试断言"布局真的被复用"用：画 100 帧，条目数不该跟着涨）
          def entry_count = @entries.size

          def font_count = @fonts.size

          private

          def build(string, size, weight, family, color, wrap_width, align)
            font = font_for(size, weight, family)
            attr_string = attributed_string(string, color)
            params = ::LibUI::FFI::DrawTextLayoutParams.malloc
            params.String = attr_string
            params.DefaultFont = font[:descriptor]
            params.Width = wrap_width
            params.Align = ::LibUI.const_get(ALIGN_CODES.fetch(align))
            layout = ::LibUI.draw_new_text_layout(params)

            width_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
            height_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_DOUBLE, Fiddle::RUBY_FREE)
            ::LibUI.draw_text_layout_extents(layout, width_ptr, height_ptr)
            ::Citrine::Native::Painter::TextEntry.new(
              text: string, size: size, weight: weight, family: family, color: color,
              wrap_width: wrap_width, align: align, layout: layout,
              attr_string: attr_string, font: font,
              measured_width: double_at(width_ptr), measured_height: double_at(height_ptr)
            )
          end

          # 字号与字重都写在**字体描述符**上（libui 用 params.DefaultFont 铺满整段文本），
          # 颜色作为属性烘进 attributed string（涨跌红绿）
          def attributed_string(string, color)
            attr_string = ::LibUI.new_attributed_string(string)
            bytes = string.bytesize
            return attr_string if bytes.zero? || color.nil?

            # uiAttributedStringSetAttribute 接管属性所有权（uiFreeAttributedString 连它们一起释放），
            # 因此这里**不能**再 uiFreeAttribute——那是 double free
            ::LibUI.attributed_string_set_attribute(attr_string, ::LibUI.new_color_attribute(*color), 0, bytes)
            attr_string
          end

          # 字体描述符缓存：默认走 uiLoadControlFont（系统控制字体，Family 由 libui 分配），
          # 显式给了 family 就自己填——那条路的 Family 指向我们 malloc 的 buffer，
          # 结构体与 buffer 都交给 Fiddle 的 RUBY_FREE 释放（见 clear! 的说明）
          def font_for(size, weight, family)
            @fonts[[size, weight, family]] ||= if family.nil?
                                                 descriptor = ::LibUI::FFI::FontDescriptor.malloc
                                                 ::LibUI.load_control_font(descriptor)
                                                 descriptor.Size = size
                                                 descriptor.Weight = weight
                                                 { descriptor: descriptor, buffer: nil, libui_owned: true }
                                               else
                                                 buffer = Fiddle::Pointer.malloc(family.bytesize + 1, Fiddle::RUBY_FREE)
                                                 buffer[0, family.bytesize + 1] = "#{family}\0"
                                                 descriptor = ::LibUI::FFI::FontDescriptor.malloc
                                                 descriptor.Family = buffer
                                                 descriptor.Size = size
                                                 descriptor.Weight = weight
                                                 descriptor.Italic = ::LibUI::TextItalicNormal
                                                 descriptor.Stretch = ::LibUI::TextStretchNormal
                                                 { descriptor: descriptor, buffer: buffer, libui_owned: false }
                                               end
          end

          def double_at(pointer) = pointer[0, Fiddle::SIZEOF_DOUBLE].unpack1("d")
        end
      end
    end
  end
end
