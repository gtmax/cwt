# frozen_string_literal: true

require "test_helper"
require "pty"
require "io/wait"

module Wotr
  class TestTuiSmoke < Minitest::Test
    include GitRepoTestHelper

    def setup
      create_test_repo
    end

    def teardown
      cleanup_test_repo
    end

    def test_tui_launches_and_quits_cleanly
      exe = File.expand_path("../../exe/wotr", __dir__)
      ruby = RbConfig.ruby

      status = nil
      output = +""

      PTY.spawn(ruby, exe, "--repo-path", @tmpdir) do |reader, writer, pid|
        # Wait for TUI to initialize and render
        sleep 1

        # Send 'q' to quit
        writer.print("q")
        writer.flush

        # Collect any output
        begin
          loop do
            break unless reader.wait_readable(2)
            output << reader.read_nonblock(4096)
          end
        rescue Errno::EIO, IOError
          # Expected when PTY process exits
        end

        # Wait for process to finish
        _, status = Process.wait2(pid)
      end

      # TUI should exit cleanly
      assert status.success?, "wotr TUI should exit with status 0, got #{status.exitstatus}"
    end
  end
end
