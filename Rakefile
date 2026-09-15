# frozen_string_literal: true

# citrine-native-libui 任务入口
#
#   rake test              桩后端语义测试 + 真控件冒烟（不开窗；CI 可跑）
#   rake gui_smoke         真窗口 + 真主循环冒烟（人工/自托管）
#   rake demo_acceptance   两个 demo 的真窗口端到端验收（仅 Windows，需同级仓库）
#   rake consumer_smoke    构建三 gem → 干净 GEM_HOME → 仓库外 require 渲染
#   rake check             test + demo_acceptance（提交前全跑）
require "rake/testtask"

ROOT = File.expand_path(__dir__)
CITRINE_LIB = File.join(ENV["CITRINE_ROOT"] || File.expand_path("../citrine", ROOT), "lib")
CORE_LIB = File.join(ENV["CITRINE_NATIVE_CORE_ROOT"] || File.expand_path("../citrine-native", ROOT), "lib")

Rake::TestTask.new do |t|
  t.libs << "lib" << CORE_LIB << CITRINE_LIB
  t.test_files = FileList["test/*_test.rb"]
  t.warning = false
end

desc "默认任务：桩测 + 真控件冒烟（不开窗）"
task default: :test

desc "真控件冒烟：真窗口 + 真主循环（窗口会闪现一下）"
task :gui_smoke do
  sh "bundle exec ruby -I#{CORE_LIB} -I#{CITRINE_LIB} -Ilib test/support/libui_scenario.rb --gui"
end

desc "两个 demo 的真窗口端到端验收（真拉起 + 真点击 + 控件标题回读；仅 Windows）"
task :demo_acceptance do
  sh "bundle exec ruby -I#{CORE_LIB} -I#{CITRINE_LIB} -Ilib test/support/demo_acceptance.rb #{ENV.fetch('DEMO', 'all')}"
end

desc "消费端冒烟：构建三 gem → 干净 GEM_HOME → 仓库外 require 并渲染"
task :consumer_smoke do
  sh "bundle exec ruby -I#{CORE_LIB} -I#{CITRINE_LIB} -Ilib test/support/consumer_smoke.rb"
end

desc "提交前检查：单测 + demo 端到端"
task check: %i[test demo_acceptance]
