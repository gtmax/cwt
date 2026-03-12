# frozen_string_literal: true

module Wotr
  class Update
    def self.handle(model, message)
      case message[:type]
      when :tick
        nil
      when :quit
        model.quit
      when :key_press
        handle_key(model, message[:key])
      when :paste
        handle_paste(model, message[:content])
      when :refresh_list
        refresh_list(model)
        :start_background_fetch
      when :create_worktree
        result = model.repository.create_worktree(message[:name])
        if result[:success]
          model.set_message("Created worktree: #{message[:name]}")
          refresh_list(model)
          model.set_mode(:normal)
          model.set_filter(String.new) # Clear filter
          # Auto-enter the new session
          { type: :resume_worktree, worktree: result[:worktree] }
        else
          model.set_message("Error: #{result[:error]}")
          nil
        end
      when :delete_worktree
        worktree = message[:worktree]
        force = message[:force] || false

        result = worktree.delete!(force: force)

        if result[:success]
          if result[:warning]
            model.set_message("Warning: #{result[:warning]}. Use 'D' to force delete.")
          else
            model.set_message("Deleted worktree #{worktree.branch || worktree.name}.")
          end
          refresh_list(model)
          :start_background_fetch
        else
          model.set_message("Error deleting: #{result[:error]}. Use 'D' to force delete.")
          nil
        end
      when :resume_worktree
        { type: :suspend_and_resume, worktree: message[:worktree] }
      when :update_status
        return nil if message[:generation] != model.fetch_generation

        target = model.find_worktree_by_path(message[:path])
        target.dirty = message[:status][:dirty] if target
        nil
      when :update_commit_age
        return nil if message[:generation] != model.fetch_generation

        target = model.find_worktree_by_path(message[:path])
        target.last_commit = message[:age] if target
        nil
      when :update_resource_icons
        model.update_resource_icons(message[:icons_by_path])
        model.finish_background_activity
        model.set_message("Checking resource status... done.")
        nil
      end
    end

    def self.handle_key(model, event)
      if model.mode == :creating
        if event.enter?
          return { type: :create_worktree, name: model.input_buffer }
        elsif event.esc?
          model.set_mode(:normal)
        elsif event.backspace?
          model.input_backspace
        elsif event.to_s.length == 1
          model.input_append(event.to_s)
        end
      elsif model.mode == :filtering
        if event.enter?
          wt = model.selected_worktree
          if wt
            model.set_filter(String.new) # Clear filter
            model.set_mode(:normal) # Exit filter mode on selection
            return { type: :resume_worktree, worktree: wt }
          else
            model.set_mode(:normal)
          end
        elsif event.esc?
          model.set_filter(String.new) # Clear filter
          model.set_mode(:normal)
        elsif event.backspace?
          model.input_backspace
        elsif event.down? || event.ctrl_n?
          model.move_selection(1)
        elsif event.up? || event.ctrl_p?
          model.move_selection(-1)
        elsif event.to_s.length == 1
          model.input_append(event.to_s)
        end
      else
        # Normal Mode
        if event.q? || event.ctrl_c? || event.esc?
          return { type: :quit }
        elsif event.j? || event.down?
          model.move_selection(1)
        elsif event.k? || event.up?
          model.move_selection(-1)
        elsif event.n?
          model.set_mode(:creating)
        elsif event.slash? # / key
          model.set_mode(:filtering)
        elsif event.d?
          wt = model.selected_worktree
          return { type: :delete_worktree, worktree: wt, force: false } if wt
        elsif event.D? # Shift+d
          wt = model.selected_worktree
          return { type: :delete_worktree, worktree: wt, force: true } if wt
        elsif event.enter?
          wt = model.selected_worktree
          return { type: :resume_worktree, worktree: wt } if wt
        elsif event.s?
          wt = model.selected_worktree
          return { type: :cd_worktree, worktree: wt } if wt
        elsif event.R? # Shift+r
          return { type: :refresh_list }
        elsif (resource_name = model.resource_shortcuts[event.to_s])
          wt = model.selected_worktree
          return { type: :acquire_resource, name: resource_name, worktree: wt } if wt
        end
      end
      nil
    end

    def self.handle_mouse(model, event)
      areas = model.mouse_areas
      return nil if areas.empty?

      # Scroll wheel → move selection
      if event.scroll_up?
        model.move_selection(-1)
        return nil
      elsif event.scroll_down?
        model.move_selection(1)
        return nil
      end

      return nil unless event.down?

      x, y = event.x, event.y

      # Row click
      if y >= areas[:list_top] && y <= areas[:list_bottom] &&
         x >= areas[:list_left] && x <= areas[:list_right]
        row = y - areas[:list_top]
        list = model.visible_worktrees
        if row >= 0 && row < list.size
          if model.selection_index == row && model.mode == :normal
            wt = list[row]
            return { type: :resume_worktree, worktree: wt } if wt
          else
            model.selection_index = row
          end
        end
        return nil
      end

      # Footer shortcut button click
      if y == areas[:key_y]
        areas[:key_buttons].each do |btn|
          next unless x >= btn[:x_start] && x <= btn[:x_end]
          return trigger_shortcut(model, btn[:key])
        end
      end

      # Resource legend button click
      if y == areas[:legend_y] && model.has_resources?
        areas[:legend_buttons].each do |btn|
          next unless x >= btn[:x_start] && x <= btn[:x_end]
          wt = model.selected_worktree
          return { type: :acquire_resource, name: btn[:resource], worktree: wt } if wt
        end
      end

      nil
    end

    def self.trigger_shortcut(model, key)
      case model.mode
      when :normal
        case key
        when 'n'     then model.set_mode(:creating)
        when '/'     then model.set_mode(:filtering)
        when 'Enter'
          wt = model.selected_worktree
          return { type: :resume_worktree, worktree: wt } if wt
        when 's'
          wt = model.selected_worktree
          return { type: :cd_worktree, worktree: wt } if wt
        when 'd'
          wt = model.selected_worktree
          return { type: :delete_worktree, worktree: wt, force: false } if wt
        when 'Esc'
          return { type: :quit }
        end
      when :creating
        case key
        when 'Enter' then return { type: :create_worktree, name: model.input_buffer }
        when 'Esc'   then model.set_mode(:normal)
        end
      when :filtering
        case key
        when 'Enter'
          wt = model.selected_worktree
          if wt
            model.set_filter(String.new)
            model.set_mode(:normal)
            return { type: :resume_worktree, worktree: wt }
          else
            model.set_mode(:normal)
          end
        when 'Esc'
          model.set_filter(String.new)
          model.set_mode(:normal)
        end
      end
      nil
    end

    def self.handle_paste(model, content)
      return nil unless model.mode == :creating || model.mode == :filtering

      # Use first line only, strip whitespace
      text = content.split("\n", 2).first.to_s.strip
      model.input_append(text)
      nil
    end

    def self.refresh_list(model)
      Git.prune_worktrees(git: model.repository.git)
      model.refresh_worktrees!
    end
  end
end
