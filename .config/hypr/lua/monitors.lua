return function(ctx)
    local shell_quote = ctx.util.shell_quote

    local display_presets = {
        laptop = {
            description = "Samsung Display Corp. 0x414D",
            mode = "3456x2160",
            scale = 1,
            workspace_base = 1,
        },
        samsung_4k_left = {
            description = "Samsung Electric Company LS32D70xE HK2X900532",
            mode = "3840x2160",
            scale = 1,
            workspace_base = 11,
        },
        samsung_4k_right = {
            description = "Samsung Electric Company LS32D70xE HK2Y400739",
            mode = "3840x2160",
            scale = 1,
            workspace_base = 21,
        },
        philips_ultrawide_left = {
            description = "Philips Consumer Electronics Company 34B2U5600 UK02421047705",
            mode = "3440x1440",
            scale = 1,
            workspace_base = 31,
        },
        philips_ultrawide_right = {
            description = "Philips Consumer Electronics Company 34B2U5600 UK02425052661",
            mode = "3440x1440",
            scale = 1,
            workspace_base = 41,
        },
        lg_4k_left = {
            description = "LG Electronics LG Ultra HD 0x00054EA3",
            mode = "3840x2160",
            scale = 1.5,
            workspace_base = 51,
        },
        lg_4k_right = {
            description = "LG Electronics LG Ultra HD 0x00055027",
            mode = "3840x2160",
            scale = 1.5,
            workspace_base = 61,
        },
        fte_left = {
            description = "Philips Consumer Electronics Company PHL 241B7Q UHB1932001606",
            mode = "1920x1080",
            scale = 1,
            workspace_base = 71,
        },
        fte_right = {
            description = "Philips Consumer Electronics Company PHL 241B7Q UHB1916006362",
            mode = "1920x1080",
            scale = 1,
            workspace_base = 81,
        },
        corner_left = {
            description = "Philips Consumer Electronics Company PHL 242B1 UK02211034482",
            mode = "1920x1080",
            scale = 1,
            workspace_base = 91,
        },
        corner_right = {
            description = "Philips Consumer Electronics Company PHL 242B1 UK02151032418",
            mode = "1920x1080",
            scale = 1,
            workspace_base = 101,
        },
    }

    local display_order = {
        "laptop",
        "samsung_4k_left",
        "samsung_4k_right",
        "philips_ultrawide_left",
        "philips_ultrawide_right",
        "lg_4k_left",
        "lg_4k_right",
        "fte_left",
        "fte_right",
        "corner_left",
        "corner_right",
    }

    local display_profiles = {
        { name = "samsung_4k_pair", outputs = { "samsung_4k_left", "samsung_4k_right" }, laptop_below = true },
        { name = "philips_ultrawide_pair", outputs = { "philips_ultrawide_left", "philips_ultrawide_right" }, laptop_below = true },
        { name = "lg_4k_pair", outputs = { "lg_4k_left", "lg_4k_right" }, laptop_below = true },
        { name = "fte_office_pair", outputs = { "fte_left", "fte_right" }, laptop_below = true },
        { name = "corner_meeting_pair", outputs = { "corner_left", "corner_right" }, laptop_below = true },
        { name = "laptop_only", outputs = { "laptop" } },
    }

    local function monitor_output(preset)
        return "desc:" .. preset.description
    end

    local function logical_size(preset)
        local width, height = preset.mode:match("^(%d+)x(%d+)")
        local scale = tonumber(preset.scale) or 1

        return math.floor((tonumber(width) or 0) / scale + 0.5),
            math.floor((tonumber(height) or 0) / scale + 0.5)
    end

    local function connected_displays()
        local present = {}

        for _, monitor in ipairs(hl.get_monitors()) do
            present[monitor.description] = true
        end

        return present
    end

    local function monitor_for_preset(preset_name)
        local preset = display_presets[preset_name]

        for _, monitor in ipairs(hl.get_monitors()) do
            if monitor.description == preset.description then
                return monitor
            end
        end

        return nil
    end

    local function preset_for_monitor(monitor)
        if not monitor then
            return nil
        end

        for preset_name, preset in pairs(display_presets) do
            if preset.description == monitor.description then
                return preset_name, preset
            end
        end

        return nil
    end

    local active_workspace_bases = {}
    local next_external_workspace_base = 11

    local function reset_workspace_assignments()
        active_workspace_bases = {
            laptop = display_presets.laptop.workspace_base,
        }
        next_external_workspace_base = 11
    end

    local function assign_workspace_base(preset_name)
        if active_workspace_bases[preset_name] then
            return active_workspace_bases[preset_name]
        end

        local base
        if preset_name == "laptop" then
            base = display_presets.laptop.workspace_base
        else
            base = next_external_workspace_base
            next_external_workspace_base = next_external_workspace_base + 10
        end

        active_workspace_bases[preset_name] = base
        return base
    end

    local function workspace_base_for_preset(preset_name)
        return active_workspace_bases[preset_name]
    end

    local function workspace_in_base_range(workspace_id, base)
        return workspace_id >= base and workspace_id < base + 10
    end

    local function workspace_in_current_range(workspace_id, preset_name)
        local base = workspace_base_for_preset(preset_name)

        return base and workspace_in_base_range(workspace_id, base)
    end

    local function current_preset_for_workspace_id(workspace_id)
        if not workspace_id or workspace_id <= 0 then
            return nil
        end

        for preset_name, base in pairs(active_workspace_bases) do
            if workspace_in_base_range(workspace_id, base) then
                return preset_name, display_presets[preset_name], base, workspace_id - base
            end
        end

        return nil
    end

    local function legacy_preset_for_workspace_id(workspace_id)
        if not workspace_id or workspace_id <= 0 then
            return nil
        end

        for preset_name, preset in pairs(display_presets) do
            if workspace_in_base_range(workspace_id, preset.workspace_base) then
                return preset_name, preset, preset.workspace_base, workspace_id - preset.workspace_base
            end
        end

        return nil
    end

    local function workspace_source_for_id(workspace_id)
        local preset_name, preset, base, offset = current_preset_for_workspace_id(workspace_id)

        if preset_name then
            return preset_name, preset, base, offset
        end

        return legacy_preset_for_workspace_id(workspace_id)
    end

    local function preset_is_present(present, preset_name)
        return present[display_presets[preset_name].description] == true
    end

    local function profile_matches(profile, present)
        for _, preset_name in ipairs(profile.outputs) do
            if not preset_is_present(present, preset_name) then
                return false
            end
        end

        return true
    end

    local function choose_display_profile(present)
        local best_profile = nil
        local best_score = -1

        for _, profile in ipairs(display_profiles) do
            if profile_matches(profile, present) then
                local score = #profile.outputs

                if profile.laptop_below and preset_is_present(present, "laptop") then
                    score = score + 1
                end

                if score > best_score then
                    best_profile = profile
                    best_score = score
                end
            end
        end

        return best_profile
    end

    local function apply_monitor_rule(preset, position)
        hl.monitor({
            output = monitor_output(preset),
            mode = preset.mode,
            position = position,
            scale = preset.scale,
        })
    end

    local function apply_workspace_rules(preset_name)
        local preset = display_presets[preset_name]
        local base = assign_workspace_base(preset_name)

        for offset = 0, 9 do
            local index = offset + 1
            local workspace = tostring(base + offset)

            hl.workspace_rule({
                workspace = workspace,
                monitor = monitor_output(preset),
                persistent = true,
                default = index == 1,
                default_name = preset_name .. ":" .. index,
            })
        end
    end

    local function hyprctl_dispatch_cmd(expression)
        return "hyprctl dispatch " .. shell_quote(expression)
    end

    local function focus_monitor_cmd(monitor_name)
        return hyprctl_dispatch_cmd("hl.dsp.focus({ monitor = " .. string.format("%q", monitor_name) .. " })")
    end

    local function focus_workspace_cmd(workspace_id)
        return hyprctl_dispatch_cmd("hl.dsp.focus({ workspace = " .. string.format("%q", tostring(workspace_id)) .. " })")
    end

    local function workspace_delta_target(delta)
        local monitor = hl.get_active_monitor()
        local preset_name = preset_for_monitor(monitor)
        local base = preset_name and workspace_base_for_preset(preset_name) or nil

        if not base then
            return nil
        end

        local workspace = hl.get_active_workspace(monitor)
        local current_id = workspace and workspace.id or base
        local current_offset = current_id - base

        if current_offset < 0 or current_offset > 9 then
            local _, _, _, source_offset = workspace_source_for_id(current_id)

            if source_offset then
                current_offset = source_offset
            else
                current_offset = 0
            end
        end

        return base + ((current_offset + delta) % 10)
    end

    function ctx.focus_workspace_delta(delta)
        local target = workspace_delta_target(delta)

        if target then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
        end
    end

    function ctx.move_window_to_workspace_delta(delta)
        local target = workspace_delta_target(delta)

        if target then
            hl.dispatch(hl.dsp.window.move({ workspace = tostring(target) }))
        end
    end

    local workspace_init_timer = nil
    local function initialize_workspace_ranges()
        local active_monitor = hl.get_active_monitor()
        local active_workspace = hl.get_active_workspace(active_monitor)
        local commands = {}

        for _, preset_name in ipairs(display_order) do
            local preset = display_presets[preset_name]
            local monitor = monitor_for_preset(preset_name)

            if monitor then
                local base = workspace_base_for_preset(preset_name)
                local restore_workspace = base

                if monitor.active_workspace and workspace_in_base_range(monitor.active_workspace.id, base) then
                    restore_workspace = monitor.active_workspace.id
                elseif monitor.active_workspace then
                    local _, _, _, source_offset = workspace_source_for_id(monitor.active_workspace.id)

                    if source_offset then
                        restore_workspace = base + source_offset
                    end
                end

                table.insert(commands, focus_monitor_cmd(monitor.name))

                for offset = 0, 9 do
                    table.insert(commands, focus_workspace_cmd(base + offset))
                end

                table.insert(commands, focus_workspace_cmd(restore_workspace))
            end
        end

        if active_monitor then
            table.insert(commands, focus_monitor_cmd(active_monitor.name))
        end

        if active_workspace then
            local active_preset_name = active_monitor and preset_for_monitor(active_monitor) or nil
            local active_base = active_preset_name and workspace_base_for_preset(active_preset_name) or nil
            local restore_workspace = active_workspace.id

            if active_base and not workspace_in_base_range(active_workspace.id, active_base) then
                local _, _, _, source_offset = workspace_source_for_id(active_workspace.id)

                if source_offset then
                    restore_workspace = active_base + source_offset
                end
            end

            table.insert(commands, focus_workspace_cmd(restore_workspace))
        end

        if #commands > 0 then
            hl.exec_cmd(table.concat(commands, " && "))
        end
    end

    local function schedule_workspace_initialization()
        if workspace_init_timer and workspace_init_timer:is_enabled() then
            workspace_init_timer:set_enabled(false)
        end

        workspace_init_timer = hl.timer(initialize_workspace_ranges, { timeout = 750, type = "oneshot" })
    end

    local function move_workspace_windows(source_workspace, target_workspace_id)
        for _, window in ipairs(source_workspace:get_windows()) do
            hl.dispatch(hl.dsp.window.move({
                window = window,
                workspace = tostring(target_workspace_id),
                follow = false,
            }))
        end
    end

    local function migrate_stale_workspace_windows()
        local active_monitor = hl.get_active_monitor()
        local active_workspace = active_monitor and hl.get_active_workspace(active_monitor) or nil
        local active_restore_workspace = nil

        for _, workspace in ipairs(hl.get_workspaces()) do
            if workspace.id > 0 and workspace.monitor then
                local target_preset_name = preset_for_monitor(workspace.monitor)
                local target_base = target_preset_name and workspace_base_for_preset(target_preset_name) or nil
                local _, _, _, source_offset = workspace_source_for_id(workspace.id)

                if target_base and source_offset and not workspace_in_base_range(workspace.id, target_base) then
                    local target_workspace_id = target_base + source_offset

                    if workspace.windows > 0 then
                        move_workspace_windows(workspace, target_workspace_id)
                    end

                    if active_workspace and active_workspace.id == workspace.id then
                        active_restore_workspace = target_workspace_id
                    end
                end
            end
        end

        if active_monitor then
            hl.dispatch(hl.dsp.focus({ monitor = active_monitor.name }))
        end

        if active_restore_workspace then
            hl.dispatch(hl.dsp.focus({ workspace = tostring(active_restore_workspace) }))
        end
    end

    local stale_workspace_migration_timer = nil
    local function schedule_stale_workspace_migration()
        if stale_workspace_migration_timer and stale_workspace_migration_timer:is_enabled() then
            stale_workspace_migration_timer:set_enabled(false)
        end

        stale_workspace_migration_timer = hl.timer(migrate_stale_workspace_windows, { timeout = 500, type = "oneshot" })
    end

    local function apply_horizontal_profile(profile, present, configured)
        local x = 0
        local max_height = 0
        local total_width = 0

        for _, preset_name in ipairs(profile.outputs) do
            local preset = display_presets[preset_name]
            local width, height = logical_size(preset)

            apply_monitor_rule(preset, x .. "x0")
            apply_workspace_rules(preset_name)
            configured[preset_name] = true
            x = x + width
            total_width = total_width + width
            max_height = math.max(max_height, height)
        end

        if profile.laptop_below and preset_is_present(present, "laptop") then
            local laptop = display_presets.laptop
            local laptop_width = logical_size(laptop)
            local laptop_x = math.max(0, math.floor((total_width - laptop_width) / 2 + 0.5))

            apply_monitor_rule(laptop, laptop_x .. "x" .. max_height)
            apply_workspace_rules("laptop")
            configured.laptop = true
        end
    end

    local function apply_known_singletons(present, configured)
        for _, preset_name in ipairs(display_order) do
            if preset_is_present(present, preset_name) and not configured[preset_name] then
                local preset = display_presets[preset_name]

                hl.monitor({
                    output = monitor_output(preset),
                    mode = preset.mode,
                    position = "auto",
                    scale = preset.scale,
                })
                apply_workspace_rules(preset_name)
            end
        end
    end

    local function apply_display_layout()
        local present = connected_displays()
        local configured = {}
        local profile = choose_display_profile(present)

        reset_workspace_assignments()
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

        if profile then
            apply_horizontal_profile(profile, present, configured)
        end

        apply_known_singletons(present, configured)
        schedule_stale_workspace_migration()
        schedule_workspace_initialization()
    end

    apply_display_layout()

    local display_relayout_timer = nil
    local function schedule_display_layout()
        if display_relayout_timer and display_relayout_timer:is_enabled() then
            display_relayout_timer:set_enabled(false)
        end

        display_relayout_timer = hl.timer(apply_display_layout, { timeout = 250, type = "oneshot" })
    end

    hl.on("monitor.added", schedule_display_layout)
    hl.on("monitor.removed", schedule_display_layout)
end
