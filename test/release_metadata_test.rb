# frozen_string_literal: true

# 后端包的发布元数据对拍（与核心包同思路，钉的是本包的名字线）。
require "minitest/autorun"
require "yaml"

class ReleaseMetadataTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def read(relative) = File.read(File.join(ROOT, relative), encoding: "UTF-8")

  def gemspec = @gemspec ||= Gem::Specification.load(File.join(ROOT, "citrine-native-libui.gemspec"))

  def version = Citrine::Native::Libui::VERSION

  def changelog_headings
    read("CHANGELOG.md").scan(/^## \[([^\]]+)\](?: - (\S+))?/).map { |name, date| [name, date] }
  end

  def test_gemspec_metadata_is_consistent
    spec = gemspec
    assert_equal "citrine-native-libui", spec.name
    assert_equal version, spec.version.to_s, "gemspec 的 version 与 version.rb 不一致"
    assert_equal ["lib"], spec.require_paths
    assert_equal spec.homepage, spec.metadata["source_code_uri"]
    assert_equal "#{spec.homepage}/blob/main/CHANGELOG.md", spec.metadata["changelog_uri"]
    assert_equal "MIT", spec.license
    # 依赖线：核心 + citrine，不许缺失
    dep_names = spec.dependencies.map(&:name)
    assert_includes dep_names, "citrine-native", "必须依赖核心包 citrine-native"
    assert_includes dep_names, "libui"
  end

  def test_changelog_has_an_entry_for_the_current_version
    released = changelog_headings.map(&:first).reject { |name| name == "Unreleased" }
    assert_includes released, version,
                    "CHANGELOG 里没有 [#{version}] 这一节（标题格式 `## [#{version}] - YYYY-MM-DD`）"
  end

  # 版本号与锁文件必须**在同一个提交里**一起更新（看提交里的那份而非工作树：
  # bundler 会在跑测试前把工作树锁文件自动修好，工作树永远修不出漂移）
  def test_committed_version_and_gemfile_lock_agree
    committed_version = git_show("lib/citrine/native/libui/version.rb")
    committed_lock = git_show("Gemfile.lock")
    skip "不在 git 仓库里（或文件未纳入版本控制）" if committed_version.empty? || committed_lock.empty?

    version_in_head = committed_version[/VERSION\s*=\s*"([^"]+)"/, 1]
    recorded = committed_lock.scan(/^    citrine-native-libui \(([^)]+)\)$/).flatten.uniq
    refute_nil version_in_head, "HEAD 的 version.rb 里读不到 VERSION"
    refute_empty recorded, "HEAD 的 Gemfile.lock 里找不到自身版本记录"
    assert_equal [version_in_head], recorded,
                 "HEAD 的 Gemfile.lock 记录 #{recorded.inspect}，而 HEAD 的 version.rb 是 #{version_in_head}" \
                 "——两者要在同一个提交里一起更新"
  end

  def git_show(path)
    `git -C "#{ROOT}" show HEAD:#{path} 2>/dev/null`
  end

  def test_releasing_doc_exists
    assert_path_exists File.join(ROOT, "RELEASING.md"), "缺少发布手册（RELEASING.md）"
  end
end
