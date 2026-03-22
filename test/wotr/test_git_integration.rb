# frozen_string_literal: true

require "test_helper"
require "wotr/repository"
require "wotr/worktree"
require "wotr/git"
require "tmpdir"
require "fileutils"

module Wotr
  class TestGitIntegration < Minitest::Test
    include GitRepoTestHelper

    # Cannot parallelize — tests share ENV for HOME and WOTR_START_POINT

    def setup
      create_test_repo
      @repo = Repository.new(@tmpdir)
      @default_branch = `git -C #{@tmpdir} rev-parse --abbrev-ref HEAD`.strip
      ENV["WOTR_START_POINT"] = @default_branch
    end

    def teardown
      ENV.delete("WOTR_START_POINT")
      FileUtils.rm_rf(@repo.worktrees_dir) if @repo
      cleanup_test_repo
    end

    # ========== Setup Marker Tests ==========

    def test_create_worktree_creates_setup_marker
      result = @repo.create_worktree("test-session")

      assert result[:success], "Worktree should be created: #{result[:error]}"
      assert result[:worktree].needs_setup?,
             "Setup marker should exist in new worktree"
    end

    def test_mark_setup_complete_removes_marker
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      assert wt.needs_setup?, "Should need setup initially"

      wt.mark_setup_complete!

      refute wt.needs_setup?, "Should not need setup after marking complete"
    end

    # ========== Setup Execution Tests ==========

    def test_run_setup_falls_back_to_symlinks
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      # Create files to symlink in root
      File.write(File.join(@tmpdir, ".env"), "SECRET=value")
      FileUtils.mkdir_p(File.join(@tmpdir, "node_modules"))
      File.write(File.join(@tmpdir, "node_modules", ".keep"), "")

      # No user script or config hooks — falls back to symlinks
      wt.run_setup!(visible: false)

      assert File.symlink?(File.join(wt.path, ".env")),
             ".env should be symlinked"
      assert File.symlink?(File.join(wt.path, "node_modules")),
             "node_modules should be symlinked"
    end

    # ========== Teardown Tests ==========

    def test_run_teardown_executes_script
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\necho 'teardown ran' > \"$WOTR_ROOT/teardown_ran.txt\"")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      output = capture_io { wt.run_teardown! }.join

      assert File.exist?(File.join(@tmpdir, "teardown_ran.txt")),
             "Teardown script should have created file"
      assert_match(/Running .wotr\/teardown/, output,
             "Should show teardown header")
    end

    def test_run_teardown_returns_ran_false_when_no_script
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      teardown_result = wt.run_teardown!

      refute teardown_result[:ran], "Should return ran: false when no script"
    end

    def test_run_teardown_returns_success_status
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\nexit 0")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      capture_io { wt.run_teardown! }
      teardown_result = wt.run_teardown!

      assert teardown_result[:ran], "Should return ran: true"
      assert teardown_result[:success], "Should return success: true"
    end

    def test_run_teardown_returns_failure_status
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\nexit 1")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      capture_io { wt.run_teardown! }
      teardown_result = wt.run_teardown!

      assert teardown_result[:ran], "Should return ran: true"
      refute teardown_result[:success], "Should return success: false"
    end

    # ========== Delete Worktree with Teardown Tests ==========

    def test_delete_runs_teardown
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"
      wt.mark_setup_complete!

      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\necho 'teardown ran' > \"$WOTR_ROOT/teardown_evidence.txt\"")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      capture_io { wt.delete!(force: true) }

      assert File.exist?(File.join(@tmpdir, "teardown_evidence.txt")),
             "Teardown should have run before removal"
    end

    def test_delete_fails_on_teardown_failure_without_force
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"
      wt.mark_setup_complete!

      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\nexit 1")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      capture_io { wt.delete!(force: false) }
      delete_result = wt.delete!(force: false)

      refute delete_result[:success], "Should fail when teardown fails"
      assert_match(/teardown.*failed/i, delete_result[:error])
      assert wt.exists?, "Worktree should still exist"
    end

    def test_delete_succeeds_on_teardown_failure_with_force
      result = @repo.create_worktree("test-session")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"
      wt.mark_setup_complete!

      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\nexit 1")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      capture_io { wt.delete!(force: true) }
      delete_result = wt.delete!(force: true)

      assert delete_result[:success], "Should succeed with force: true"
      refute wt.exists?, "Worktree should be removed"
    end

    # ========== Full Workflow Tests ==========

    def test_full_workflow_create_setup_teardown_delete
      # 1. Create worktree
      result = @repo.create_worktree("full-workflow")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"
      assert wt.needs_setup?

      # 2. Create teardown script
      FileUtils.mkdir_p(@repo.config_dir)
      File.write(@repo.teardown_script_path, "#!/bin/bash\necho 'teardown' > \"$WOTR_ROOT/teardown.log\"")
      FileUtils.chmod(0o755, @repo.teardown_script_path)

      # 3. Run setup (simulating first resume — falls back to default symlinks)
      wt.run_setup!(visible: false)
      wt.mark_setup_complete!
      refute wt.needs_setup?

      # 4. Second resume should NOT run setup
      refute wt.needs_setup?, "Setup should not run again"

      # 5. Delete worktree (runs teardown)
      capture_io { wt.delete!(force: true) }
      assert File.exist?(File.join(@tmpdir, "teardown.log"))
      refute wt.exists?
    end

    # ========== Git Status Tests ==========

    def test_get_status_detects_dirty_worktree
      result = @repo.create_worktree("status-test")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      wt.mark_setup_complete!

      status = Git.get_status(wt.path)
      refute status[:dirty], "Worktree should be clean initially"

      File.write(File.join(wt.path, "uncommitted.txt"), "dirty")

      status = Git.get_status(wt.path)
      assert status[:dirty], "Worktree should be dirty after adding file"
    end

    # ========== Repository Discovery Tests ==========

    def test_discover_works_from_worktree
      result = @repo.create_worktree("discover-test")
      wt = result[:worktree]
      assert result[:success], "Expected success: #{result[:error]}"

      discovered = Repository.discover(wt.path)
      assert_equal File.realpath(@tmpdir), File.realpath(discovered.root)
    end
  end
end
