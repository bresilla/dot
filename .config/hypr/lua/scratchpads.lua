return function(ctx)
    local M = {}
    local scratchpad_tag = "scratchpad"

    local function special_workspace_has_windows(name)
        return #hl.get_workspace_windows("special:" .. name) > 0
    end

    local function special_workspace_selector(name)
        return "special:" .. name
    end

    local function is_named_special_workspace(workspace, name)
        local selector = special_workspace_selector(name)
        return workspace
            and workspace.special
            and (workspace.name == selector or workspace.name == name or workspace.config_name == selector or workspace.config_name == name)
    end

    local function visible_special_monitor(name)
        for _, monitor in ipairs(hl.get_monitors()) do
            local workspace = monitor.active_special_workspace or hl.get_active_special_workspace(monitor)

            if is_named_special_workspace(workspace, name) then
                return monitor
            end
        end

        return nil
    end

    local function window_has_tag(window, tag)
        local tags = window and window.tags

        if type(tags) == "string" then
            return (" " .. tags .. " "):match("%s" .. tag .. "%*?%s") ~= nil
        end

        if type(tags) == "table" then
            for _, window_tag in pairs(tags) do
                if window_tag == tag or window_tag == tag .. "*" then
                    return true
                end
            end
        end

        return false
    end

    local function active_regular_workspace_for_monitor(monitor)
        local workspace = monitor and monitor.active_workspace or nil

        if workspace and not workspace.special then
            return workspace
        end

        workspace = monitor and hl.get_active_workspace(monitor)

        if workspace and not workspace.special then
            return workspace
        end

        return nil
    end

    local function move_launched_window_to_regular_workspace(window)
        if not window or not window.workspace or not window.workspace.special then
            return
        end

        if window_has_tag(window, scratchpad_tag) then
            return
        end

        local workspace = active_regular_workspace_for_monitor(window.monitor or hl.get_active_monitor())

        if not workspace then
            return
        end

        hl.dispatch(hl.dsp.window.move({
            window = window,
            workspace = workspace,
            follow = false,
        }))
    end

    hl.on("window.open", function(window)
        hl.timer(function()
            move_launched_window_to_regular_workspace(hl.get_window(window) or window)
        end, { timeout = 20, type = "oneshot" })
    end)

    local function center_special_windows(name)
        for _, window in ipairs(hl.get_workspace_windows(special_workspace_selector(name))) do
            hl.dispatch(hl.dsp.window.center({ window = window }))
        end
    end

    local function resolve_scratch_size_component(component, monitor, axis)
        if type(component) == "number" then
            return math.floor(component)
        end

        if type(component) ~= "string" or not monitor then
            return nil
        end

        local dimension = axis == "x" and monitor.width or monitor.height
        local percent = component:match("^([%d%.]+)%%$")

        if percent then
            return math.floor(dimension * tonumber(percent) / 100)
        end

        local monitor_axis, multiplier = component:match("^monitor_([wh])%s*%*%s*([%d%.]+)$")

        if monitor_axis and multiplier then
            local base = monitor_axis == "w" and monitor.width or monitor.height
            return math.floor(base * tonumber(multiplier))
        end

        local pixels = tonumber(component)

        if pixels then
            return math.floor(pixels)
        end

        return nil
    end

    local function resolve_scratch_size(size, monitor)
        if type(size) == "string" then
            local width, height = size:match("^%s*(%S+)%s+(%S+)%s*$")

            if width and height then
                size = { width, height }
            end
        end

        if type(size) ~= "table" then
            return nil, nil
        end

        local width = resolve_scratch_size_component(size[1], monitor, "x")
        local height = resolve_scratch_size_component(size[2], monitor, "y")

        if monitor then
            local max_width = math.floor(monitor.width * 0.86)
            local max_height = math.floor(monitor.height * 0.82)
            width = width and math.min(width, max_width) or nil
            height = height and math.min(height, max_height) or nil
        end

        return width, height
    end

    local function resize_special_windows(name, rules, monitor)
        if not rules or not rules.size then
            return
        end

        local width, height = resolve_scratch_size(rules.size, monitor or hl.get_active_monitor())

        if not width or not height then
            return
        end

        for _, window in ipairs(hl.get_workspace_windows(special_workspace_selector(name))) do
            hl.dispatch(hl.dsp.window.resize({
                window = window,
                x = width,
                y = height,
                relative = false,
            }))
        end
    end

    local function move_special_to_active_monitor(name)
        local monitor = hl.get_active_monitor()

        if monitor then
            hl.dispatch(hl.dsp.workspace.move({
                workspace = special_workspace_selector(name),
                monitor = monitor.name,
            }))
        end

        return monitor
    end

    local function set_animations_enabled(enabled)
        hl.config({
            animations = {
                enabled = enabled,
            },
        })
    end

    local function disable_animations_temporarily(duration)
        set_animations_enabled(false)

        hl.timer(function()
            set_animations_enabled(true)
        end, { timeout = duration, type = "oneshot" })
    end

    local function prepare_special_scratch(name, rules)
        local monitor = move_special_to_active_monitor(name)
        resize_special_windows(name, rules, monitor)
        center_special_windows(name)
    end

    local function special_visible_on_active_monitor(name)
        local monitor = hl.get_active_monitor()

        if not monitor then
            return false
        end

        local workspace = monitor.active_special_workspace or hl.get_active_special_workspace(monitor)
        return is_named_special_workspace(workspace, name)
    end

    local function ensure_special_visible_on_active_monitor(name)
        if not special_visible_on_active_monitor(name) then
            hl.dispatch(hl.dsp.workspace.toggle_special(name))
        end
    end

    local function show_special_scratch(name, rules)
        disable_animations_temporarily(150)
        prepare_special_scratch(name, rules)

        hl.timer(function()
            ensure_special_visible_on_active_monitor(name)

            hl.timer(function()
                center_special_windows(name)
            end, { timeout = 50, type = "oneshot" })
        end, { timeout = 20, type = "oneshot" })
    end

    function M.toggle(name, cmd, rules)
        if special_workspace_has_windows(name) then
            local monitor = hl.get_active_monitor()
            local visible_monitor = visible_special_monitor(name)

            if monitor and visible_monitor and monitor.name ~= visible_monitor.name then
                disable_animations_temporarily(180)
                hl.dispatch(hl.dsp.workspace.toggle_special(name))

                hl.timer(function()
                    prepare_special_scratch(name, rules)
                end, { timeout = 20, type = "oneshot" })

                hl.timer(function()
                    ensure_special_visible_on_active_monitor(name)
                end, { timeout = 60, type = "oneshot" })

                hl.timer(function()
                    center_special_windows(name)
                end, { timeout = 100, type = "oneshot" })
            elseif visible_monitor then
                hl.dispatch(hl.dsp.workspace.toggle_special(name))
            else
                show_special_scratch(name, rules)
            end

            return
        end

        local exec_rules = {
            float = true,
            center = true,
            tag = "+" .. scratchpad_tag,
            workspace = special_workspace_selector(name),
        }

        for key, value in pairs(rules or {}) do
            exec_rules[key] = value
        end

        hl.exec_cmd(cmd, exec_rules)
    end

    function M.bind(keys, name, cmd, rules)
        hl.bind(keys, function()
            M.toggle(name, cmd, rules)
        end)
    end

    ctx.scratchpads = M
    return M
end
