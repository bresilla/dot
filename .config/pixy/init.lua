local pixy = require("pixy")

-- The caller's cwd when it passed one, else the environment's.
local function cwd_of(ctx)
  return ctx.values.cwd or pixy.host.env("PWD")
end
local git = require("pixy.segments.git")
local system = require("pixy.segments.system")
local progress = require("pixy.segments.progress")

local style_git = {bg = 1, fg = 0}
local style_host = {bg = 237, fg = 15, italic = true}
local style_directory = {bg = 237, fg = 15}
local style_recording = {bg = 1, fg = 15, bold = true}

local function value(ctx, name)
  if ctx.values and ctx.values[name] ~= nil then return ctx.values[name] end
  return nil
end

local function pane_value(ctx, name)
  local direct = value(ctx, name)
  if direct ~= nil then return direct end
  local pane = value(ctx, "pane")
  if type(pane) == "table" then return pane[name] end
  return nil
end

local function trim(text)
  if type(text) ~= "string" then return nil end
  local result = text:match("^%s*(.-)%s*$")
  if result == "" then return nil end
  return result
end

local function execute(argv, options)
  local ok, result = pcall(pixy.host.exec, argv, options or {})
  if not ok or not result or result.status ~= 0 then return nil end
  return trim(result.stdout)
end

local function overridden(ctx, name, fallback)
  local selected = value(ctx, name)
  if selected == false then return nil end
  if selected ~= nil then return selected end
  return fallback()
end

local function fish_path(path)
  if not path or path == "" then return "/" end
  local home = pixy.host.env("HOME") or ""
  local current = path
  if home ~= "" and current:sub(1, #home) == home then current = "~" .. current:sub(#home + 1) end
  local prefix = ""
  if current:sub(1, 1) == "~" then
    prefix = "~"
    current = current:sub(2)
  elseif current:sub(1, 1) == "/" then
    prefix = "/"
    current = current:sub(2)
  end
  local parts = {}
  for part in current:gmatch("[^/]+") do parts[#parts + 1] = part end
  if #parts == 0 then return prefix end
  for index = 1, #parts - 1 do
    local part = parts[index]
    parts[index] = part:sub(1, 1) == "." and "." .. part:sub(2, 2) or part:sub(1, 1)
  end
  return prefix .. table.concat(parts, "/")
end

local function hostname(ctx)
  return trim(tostring(overridden(ctx, "hostname", function()
    return system.hostname() or execute({"hostname"}, {timeout_ms = 30, ttl_ms = 60000})
  end) or ""))
end

local function username(ctx)
  return trim(tostring(overridden(ctx, "username", system.username) or ""))
end

local function distro(ctx)
  return trim(tostring(overridden(ctx, "distro", function()
    local home = pixy.host.env("HOME")
    if not home then return nil end
    return execute({home .. "/.local/sbin/distrologo"}, {timeout_ms = 100, ttl_ms = 86400000})
  end) or ""))
end

local function container(ctx)
  return trim(tostring(overridden(ctx, "container", function()
    return execute({"systemd-detect-virt"}, {timeout_ms = 50, ttl_ms = 86400000})
  end) or ""))
end

local function scratch_count(ctx)
  local selected = value(ctx, "scratch_count")
  if selected ~= nil then return tonumber(selected) or 0 end
  local output = execute({"oslo", "scratch", "-l"}, {timeout_ms = 100, ttl_ms = 5000})
  if not output then return 0 end
  local count = 0
  for _ in (output .. "\n"):gmatch("[^\n]+\n") do count = count + 1 end
  return count
end

local function clock(ctx)
  return trim(tostring(overridden(ctx, "time", function()
    -- In process, from the time pixy already holds. `date` costs a fork a
    -- prompt and reads the zone with whatever libc is first on PATH; the nix
    -- coreutils one carries no zoneinfo under its own TZDIR, so it cannot
    -- resolve $TZ and quietly answers UTC -- two hours behind here.
    return os.date("%H:%M:%S", math.floor((tonumber(ctx and ctx.now_ms) or 0) / 1000))
  end) or "")) or "--:--:--"
end

local function prompt_ssh()
  if not pixy.host.env("SSH_CONNECTION") then return nil end
  return pixy.text(" //", style_host)
end

local function prompt_hostname(ctx)
  local text = hostname(ctx)
  if not text then return nil end
  local asp = pixy.host.env("SSH_CONNECTION") and "" or " "
  return pixy.text(asp .. text .. " ", style_host)
end

local function prompt_distro(ctx)
  local text = distro(ctx)
  if not text then return nil end
  return pixy.text(" " .. text, style_git)
end

local function prompt_username(ctx)
  local text = username(ctx)
  if not text then return nil end
  return pixy.text(" " .. text .. " ", style_git)
end

local function prompt_direnv()
  if not pixy.host.env("DIRENV_DIR") then return nil end
  return pixy.text("▓", style_git)
end

local function prompt_nix()
  if not pixy.host.env("IN_NIX_SHELL") then return nil end
  return pixy.row({pixy.text("|", {fg = 7}), pixy.text(" ❄ ", style_directory)})
end

local function prompt_sudo(ctx)
  local active = value(ctx, "sudo")
  if active == nil then active = system.sudo(ctx) end
  if active ~= true then return nil end
  return pixy.text(" sudo ", {bold = true, bg = 240, fg = 171})
end

local function prompt_scratch(ctx)
  local name = trim(pixy.host.env("SCRATCH") or "")
  if name then
    return pixy.row({pixy.text("|", {fg = 7}), pixy.text(" " .. name .. " ", style_host)})
  end
  local count = scratch_count(ctx)
  if count <= 0 then return nil end
  return pixy.row({pixy.text("|", {fg = 7}), pixy.text(" " .. tostring(count) .. " ", style_host)})
end

local function prompt_status(ctx)
  local status = tonumber(ctx.values.status or 0) or 0
  if status == 0 then return nil end
  return pixy.text(" " .. tostring(status) .. " ", {bg = 0, fg = 9})
end

local function prompt_container(ctx)
  local kind = container(ctx)
  if not kind or kind == "none" then return nil end
  local mark = kind == "lxc" and " >> " or " :: "
  return pixy.row({pixy.text(" ", {bg = 0, fg = 0}), pixy.text(mark, {bg = 5, fg = 0})})
end

local function prompt_language(ctx)
  if not ctx.values.language then return nil end
  return pixy.text(ctx.values.language == "lua" and " λ " or " $ ", {bg = 0, fg = 1})
end

local function prompt_pod(ctx)
  local name = trim(tostring(value(ctx, "pod_name") or pixy.host.env("HEXE_POD_NAME") or ""))
  if not name then return nil end
  return pixy.text("| " .. name .. " |", {bg = 5, fg = 0})
end

local function prompt_directory(ctx)
  if not cwd_of(ctx) then return nil end
  return pixy.text(" " .. fish_path(cwd_of(ctx)) .. " ", style_directory)
end

local function prompt_git_branch(ctx)
  local branch = git.branch(ctx)
  if not branch then return nil end
  return pixy.text(" " .. branch .. " ", style_git)
end

local function prompt_git_status(ctx)
  local text = value(ctx, "git_status_text")
  if text == false then return nil end
  if text == nil then
    local status = git.status(ctx)
    if status == "dirty" then text = "!" end
  end
  text = trim(tostring(text or ""))
  if not text then return nil end
  return pixy.text(" " .. text .. " ", style_git)
end

-- **The turning glyph.** `frame` is counted by oslo and passed in with `--set frame=$frame`; pixy
-- is a fresh process every time and has no memory of the last one, so the number has to arrive
-- from outside. Nothing is drawn when it does not — an oslo without `every` on this prompt, or an
-- older one that has never heard of `$frame`, simply has no spinner rather than a broken prompt.
--
-- **The whole cell, not the top of it.** A braille cell is 4 rows by 2, and the familiar
-- `⠋ ⠙ ⠹ …` spinner only ever lights the top three rows — so it sits high against a background,
-- with a visible gap under it, which is what makes it look wrong beside a full-height block. These
-- eight light seven of the eight dots each, with the gap travelling round the ring, so every frame
-- fills the cell top to bottom and only the hole moves.
local SPIN_FRAMES = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" }

local function prompt_spinner(ctx)
  local n = tonumber(value(ctx, "frame"))
  if not n then return nil end
  return pixy.text(" " .. SPIN_FRAMES[(math.floor(n) % #SPIN_FRAMES) + 1] .. " ", style_directory)
end

local function prompt_vimode(ctx)
  if not ctx.values.vimode then return nil end
  local marks = {I = " I ", insert = " I ", N = " N ", normal = " N ", R = " R ", replace = " R ", V = " V ", visual = " V "}
  local mark = marks[ctx.values.vimode] or " " .. ctx.values.vimode .. " "
  local resting = ctx.values.vimode == "I" or ctx.values.vimode == "insert"
  return pixy.text(mark, resting and style_directory or style_git)
end

local function status_spinner(ctx)
  local running = pane_value(ctx, "shell_running") == true and pane_value(ctx, "alt_screen") ~= true
  if not running and pane_value(ctx, "adhoc_float") ~= true then return nil end
  local supplied = trim(tostring(value(ctx, "spinner") or ""))
  if supplied then return pixy.text(" " .. supplied .. " ", {bg = 0, fg = 1}) end
  return pixy.spinner({
    kind = "knight_rider",
    width = 10,
    step = 40,
    hold = 20,
    colors = {243, 242, 241, 240, 239, 238, 237, 236},
    bg = 0,
    prefix = pixy.text(" ", {bg = 0}),
    suffix = pixy.text(" ", {bg = 0}),
    started_at_ms = ctx.values.started_at_ms,
  })
end

local function pokemon_sprite(ctx)
  if value(ctx, "sprite_visible") == false then return nil end
  local pane = value(ctx, "pane")
  if type(pane) ~= "table" then pane = {} end
  local name = trim(tostring(value(ctx, "sprite_name") or pane.pokemon_name or pane.name or "pikachu")) or "pikachu"
  local shiny = value(ctx, "sprite_shiny") == true
  local item = trim(tostring(value(ctx, "sprite_item") or ""))
  if not item then item = (shiny and "shiny/" or "regular/") .. name end
  local fallback = (shiny and "shiny/" or "regular/") .. "pikachu"
  local frames = value(ctx, "sprite_frames") or value(ctx, "sprite_frame")
  return pixy.sprite({
    pack = tostring(value(ctx, "sprite_pack") or "pokemon"),
    name = item,
    fallback_name = fallback,
    frames = frames,
    format = value(ctx, "sprite_format") or "ansi",
    position = value(ctx, "sprite_position") or "topright",
    transparent = true,
  })
end

local function status_random(ctx)
  local running = pane_value(ctx, "shell_running") == true and pane_value(ctx, "alt_screen") ~= true
  if not running and pane_value(ctx, "adhoc_float") ~= true then return nil end
  local text = trim(tostring(value(ctx, "randomdo") or ""))
  if not text then text = system.random(ctx, {"do", "make", "build", "ship"}) end
  return text and pixy.text(text .. " ", {bg = 0, fg = 1}) or nil
end

local function status_tabs(ctx)
  local tabs = value(ctx, "tabs")
  if type(tabs) ~= "table" then return nil end
  local children = {}
  for index, tab in ipairs(tabs) do
    local title = type(tab) == "table" and tostring(tab.title or tab.name or index) or tostring(tab)
    local active = type(tab) == "table" and tab.active == true or value(ctx, "active_tab") == index - 1
    if #children > 0 then children[#children + 1] = pixy.text("|", {fg = 7}) end
    children[#children + 1] = pixy.text(" " .. title .. " ", active and style_git or {bg = 237, fg = 250})
  end
  return pixy.row(children)
end

local function status_battery(ctx)
  local battery
  if value(ctx, "battery_percent") ~= nil then
    battery = {percent = tonumber(value(ctx, "battery_percent")), status = value(ctx, "battery_status")}
  else
    battery = system.battery(ctx)
  end
  if not battery or not battery.percent then return nil end
  return pixy.text(" " .. tostring(battery.percent) .. "% ", {bg = 237, fg = 250})
end

local function status_recording(ctx)
  local active = value(ctx, "recording") == true
  return pixy.text(active and " REC " or " rec ", style_recording)
end

local function title(ctx, container_title)
  local text = trim(tostring(value(ctx, "title") or ""))
  if not text then return nil end
  local edge = container_title and {bg = 0, fg = 1} or {bg = 1, fg = 1}
  local body = value(ctx, "active") == false and {bg = 237, fg = 250} or style_git
  return pixy.row({pixy.text(" ", edge), pixy.text(text, body), pixy.text(" ", edge)})
end

local function popup(ctx, default_offset)
  local message = tostring(value(ctx, "message") or "")
  local block = pixy.style(pixy.pad(message, {left = 3, right = 3, top = 1, bottom = 1}), {
    bg = 1,
    fg = 232,
    bold = true,
  })
  local scope = tostring(value(ctx, "scope") or "mux")
  local configured_offset = default_offset and (scope == "pane" and 2 or 3) or 0
  local offset = tonumber(value(ctx, "offset")) or configured_offset
  local maximum = math.max(0, (ctx.height or 3) - 3)
  local top = math.max(0, math.min(maximum, math.floor(maximum / 2) + offset))
  local values = {}
  for _ = 1, top do values[#values + 1] = pixy.text("") end
  values[#values + 1] = pixy.regions({center = {block}})
  return pixy.surface(values)
end

local border = {
  top_left = "╔",
  top_right = "╗",
  bottom_left = "╚",
  bottom_right = "╝",
  horizontal = "═",
  vertical = "║",
}

local function frame_line(width, left, right, horizontal, frame_style, title_node, title_width, title_right)
  if width <= 1 then return pixy.text(left, frame_style) end
  local inside = width - 2
  local children = {pixy.text(left, frame_style)}
  if title_node and title_width <= inside then
    local remaining = inside - title_width
    local before = title_right and remaining or 0
    local after = title_right and 0 or remaining
    if before > 0 then children[#children + 1] = pixy.text(string.rep(horizontal, before), frame_style) end
    children[#children + 1] = title_node
    if after > 0 then children[#children + 1] = pixy.text(string.rep(horizontal, after), frame_style) end
  else
    children[#children + 1] = pixy.text(string.rep(horizontal, inside), frame_style)
  end
  children[#children + 1] = pixy.text(right, frame_style)
  return pixy.row(children)
end

local function frame(ctx, container_frame)
  local width = math.max(1, tonumber(ctx.width) or 1)
  local height = math.max(1, tonumber(ctx.height) or 1)
  local shadow = container_frame and value(ctx, "shadow") ~= false and width > 1 and height > 1
  local frame_width = shadow and width - 1 or width
  local frame_height = shadow and height - 1 or height
  local active = value(ctx, "active") ~= false
  local frame_style = {fg = active and 1 or 237}
  local title_node = title(ctx, container_frame)
  local title_text = trim(tostring(value(ctx, "title") or ""))
  local title_width = title_text and pixy.host.cell_width(title_text) + 2 or 0
  local title_top = container_frame
  local lines = {
    frame_line(frame_width, border.top_left, border.top_right, border.horizontal, frame_style,
      title_top and title_node or nil, title_width, true),
  }
  for _ = 2, frame_height - 1 do
    if frame_width <= 1 then
      lines[#lines + 1] = pixy.text(border.vertical, frame_style)
    else
      lines[#lines + 1] = pixy.row({
        pixy.text(border.vertical, frame_style),
        pixy.transparent(frame_width - 2),
        pixy.text(border.vertical, frame_style),
      })
    end
  end
  if frame_height > 1 then
    lines[#lines + 1] = frame_line(frame_width, border.bottom_left, border.bottom_right,
      border.horizontal, frame_style, title_top and nil or title_node, title_width, true)
  end
  if shadow then
    for index = 2, #lines do
      lines[index] = pixy.row({lines[index], pixy.text(" ", {bg = 236})})
    end
    lines[#lines + 1] = pixy.row({pixy.transparent(1), pixy.text(string.rep(" ", frame_width), {bg = 236})})
  end
  return pixy.surface(lines)
end

local function chooser(ctx)
  local choices = value(ctx, "choices")
  if type(choices) ~= "table" then return nil end
  local selected = math.max(1, tonumber(value(ctx, "selected")) or 1)
  local first = math.max(1, selected - 9)
  local last = math.min(#choices, first + 9)
  local lines = {}
  for index = first, last do
    local item = choices[index]
    local label = type(item) == "table" and tostring(item.label or item.name or index) or tostring(item)
    local row_style = index == selected and {fg = 1, bg = 232} or {fg = 232, bg = 1}
    lines[#lines + 1] = pixy.region(
      pixy.style(pixy.pad(label, {left = 1, right = 1}), row_style),
      {id = "choice." .. tostring(index), actions = {left = "choose." .. tostring(index)}}
    )
  end
  return pixy.surface(lines)
end

local report_colors = {
  loaded = 2,
  unloaded = 8,
  blocked = 3,
  denied = 1,
  failed = 1,
  watched = 6,
  added = 2,
  changed = 3,
  removed = 1,
  aliases = 5,
  value = 8,
}

local function home_path(path)
  local home = pixy.host.env("HOME") or ""
  if home ~= "" and path:sub(1, #home) == home then return "~" .. path:sub(#home + 1) end
  return path
end

local function report_head(state, owner, problem)
  local color = report_colors[state] or report_colors.failed
  local word = state == "unloaded" and "left" or state
  local rest = home_path(owner or "")
  if state == "blocked" then rest = rest .. "  → direnv allow" end
  if state ~= "loaded" and state ~= "unloaded" and state ~= "blocked" and state ~= "denied" then
    rest = rest .. "  " .. tostring(problem or "")
  end
  return pixy.row({
    pixy.text("direnv", {fg = color, bold = true}),
    pixy.text(" " .. word, {fg = color}),
    pixy.text(rest ~= "" and " " .. rest or ""),
  })
end

local function report_row(ctx, label, text, color)
  local prefix = label .. " "
  local available = math.max(0, (ctx.width or 80) - pixy.host.cell_width(prefix))
  local value_color = (label == "TOP_HEAD" or label == "PATH") and report_colors.value or color
  return pixy.row({
    pixy.text(label, {fg = color}),
    pixy.text(" "),
    pixy.truncate(pixy.text(text, {fg = value_color}), available, "…"),
  })
end

local function direnv_report(ctx)
  local report = value(ctx, "direnv")
  if type(report) ~= "table" or not report.state then return nil end
  local lines = {report_head(report.state, report.owner, report.problem)}
  if report.state ~= "loaded" then return pixy.surface(lines) end
  for _, name in ipairs({"TOP_HEAD", "PATH"}) do
    local watched = report.watched and report.watched[name]
    if watched ~= nil then
      lines[#lines + 1] = report_row(ctx, name, tostring(watched), report_colors.watched)
    end
  end
  local grouped = {}
  for _, changed in ipairs(report.changed or {}) do
    if changed.name ~= "TOP_HEAD" and changed.name ~= "PATH" then
      local change = tostring(changed.change or "changed")
      grouped[change] = grouped[change] or {}
      grouped[change][#grouped[change] + 1] = tostring(changed.name or "")
    end
  end
  for _, change in ipairs({"added", "changed", "removed"}) do
    if grouped[change] and #grouped[change] > 0 then
      lines[#lines + 1] = report_row(ctx, change, table.concat(grouped[change], " "), report_colors[change])
    end
  end
  local aliases = {}
  for _, alias in ipairs(report.aliases or {}) do
    aliases[#aliases + 1] = type(alias) == "table" and tostring(alias.name or "") or tostring(alias)
  end
  if #aliases > 0 then
    lines[#lines + 1] = report_row(ctx, "aliases", table.concat(aliases, " "), report_colors.aliases)
  end
  return pixy.surface(lines)
end

local status_left = {
  pixy.segment("clock", function(ctx)
    return pixy.text(" " .. clock(ctx) .. " ", {bg = 237, fg = 250, bold = true})
  end, {priority = 10}),
  pixy.segment("session", function(ctx)
    local session = trim(tostring(value(ctx, "session") or ""))
    return session and pixy.text("| " .. session .. " |", style_git) or nil
  end, {priority = 30}),
  pixy.segment("spinner", status_spinner, {priority = 20}),
  pixy.segment("random", status_random, {priority = 200000}),

}

local status_center = {
  pixy.segment("tabs", status_tabs, {priority = 1}),

}

local status_right = {
  -- OSC 9;4 as the host reported it: a bar when it knows how far along the
  -- work is, a sweeping block when it does not, nothing when nothing runs.
  pixy.segment("progress", function(ctx)
    local bar = progress.segment({width = 10, bg = 0, label = true}, ctx)
    if not bar then return nil end
    return pixy.row({bar, pixy.text(" ", {bg = 0})})
  end, {priority = 8}),
  pixy.segment("recording", status_recording, {
    priority = 11,
    id = "recording",
    actions = {left = "record.switch", right = "record.stop"},
    hover_style = {bg = 15, fg = 1, bold = true},
    press_styles = {
      left = {bg = 2, fg = 0, bold = true},
      middle = {bg = 3, fg = 0, bold = true},
      right = style_recording,
    },
  }),
  pixy.segment("battery", status_battery, {priority = 40}),
  pixy.segment("directory", function(ctx)
    local cwd = cwd_of(ctx) or pane_value(ctx, "cwd")
    return cwd and pixy.text(" " .. fish_path(cwd) .. " ", style_directory) or nil
  end, {priority = 50}),

}

local status_bar = {}
for _, segment in ipairs(status_left) do status_bar[#status_bar + 1] = segment end
status_bar[#status_bar + 1] = pixy.segment("gap_left", function() return pixy.spacer() end)
for _, segment in ipairs(status_center) do status_bar[#status_bar + 1] = segment end
status_bar[#status_bar + 1] = pixy.segment("gap_right", function() return pixy.spacer() end)
for _, segment in ipairs(status_right) do status_bar[#status_bar + 1] = segment end

pixy.zone("prompt.left", {
  pixy.segment("ssh", prompt_ssh, {priority = 60}),
  pixy.segment("hostname", prompt_hostname, {priority = 15}),
  pixy.segment("distro", prompt_distro, {priority = 10}),
  pixy.segment("username", prompt_username, {priority = 1}),
  pixy.segment("direnv", prompt_direnv, {priority = 25}),
  pixy.segment("nix", prompt_nix, {priority = 24}),
  pixy.segment("sudo", prompt_sudo, {priority = 6}),
  pixy.segment("scratch", prompt_scratch, {priority = 35}),
  pixy.segment("status", prompt_status, {priority = 3}),
  pixy.segment("container", prompt_container, {priority = 50}),
  pixy.segment("separator", function() return pixy.text("|", {fg = 7}) end, {priority = 20}),
  pixy.segment("language", prompt_language, {priority = 3}),
})

pixy.zone("prompt.right", {
  pixy.segment("spinner", prompt_spinner, {priority = 1}),
  pixy.segment("pod", prompt_pod, {priority = 1}),
  pixy.segment("directory", prompt_directory, {priority = 2}),
  pixy.segment("git_branch", prompt_git_branch, {priority = 4}),
  pixy.segment("git_status", prompt_git_status, {priority = 5}),
  pixy.segment("vimode", prompt_vimode, {priority = 2}),
})


-- **The whole line a finished command leaves behind.** oslo clears the prompt when a line runs and
-- puts this in its place; everything the row shows is drawn here, colours included. oslo supplies
-- only what pixy cannot know — the width (as `--width`, so `ctx.width`), how the command *above*
-- ended, and whether this is the first row of the command or one hanging under it.
--
--   ---[ 0 ]--------------------------------------[ cargo test --lib ]---
--
-- The status is the command *before* this one: a frame is drawn between Enter and the command
-- starting, so it can never report its own. That is why it sits at the left, directly under the
-- last line of the output it is closing off.
--
-- **Indexed colours, so a palette can retint them.** `fg = 1` is entry 1 rather than a hex value,
-- which is what lets `OSC 1330` recolour a whole pane's dividers after the fact.
local style_divider = {fg = 1}
local style_command = {fg = 15, bold = true}
local TRANSCRIPT_TAIL = 3

-- **`or ""` is wrong for a context value.** pixy reads `--set cmd=false` as the boolean, and Lua's
-- `or` treats that as absent — so the command `false` rendered nothing at all and the row silently
-- fell back to oslo's own drawing. Anything that is not nil is a value, including `false`.
local function said(ctx, name)
  local raw = value(ctx, name)
  if raw == nil then return nil end
  return trim(tostring(raw))
end

local function transcript_row(ctx)
  local cmd = said(ctx, "cmd")
  if not cmd then return nil end
  local cols = math.max(1, tonumber(ctx.width) or 80)
  local status = said(ctx, "status")
  local first = said(ctx, "first")

  -- A row hanging under the first draws its brackets and nothing else; oslo indents it.
  if not first then
    return pixy.row({
      pixy.text("[ ", style_divider),
      pixy.text(cmd, style_command),
      pixy.text(" ]", style_divider),
    })
  end

  local tail = string.rep("-", TRANSCRIPT_TAIL)
  local opened = status ~= nil and (tail .. "[ " .. status .. " ]") or ""
  local fill = cols - (#cmd + 4) - TRANSCRIPT_TAIL - #opened
  if fill < 0 then fill = 0 end

  return pixy.row({
    pixy.text(opened .. string.rep("-", fill) .. "[ ", style_divider),
    pixy.text(cmd, style_command),
    pixy.text(" ]" .. tail, style_divider),
  })
end

pixy.zone("transcript", {
  pixy.segment("row", transcript_row, {priority = 1}),
})

pixy.zone("status.left", status_left)
pixy.zone("status.center", status_center)
pixy.zone("status.right", status_right)
pixy.zone("status", status_bar)
pixy.zone("overlay", {
  pixy.segment("sprite", pokemon_sprite),
})

pixy.zone("float.title", {
  pixy.segment("content", function(ctx) return title(ctx, false) end),
})

pixy.zone("container.title", {
  pixy.segment("content", function(ctx) return title(ctx, true) end),
})

pixy.zone("float.frame", {
  pixy.segment("border", function(ctx) return frame(ctx, false) end),
})

pixy.zone("container.frame", {
  pixy.segment("border", function(ctx) return frame(ctx, true) end),
})

pixy.zone("split.vertical", {
  pixy.segment("divider", function(ctx)
    return pixy.text("│", {fg = value(ctx, "active") == false and 237 or 1})
  end),
})

pixy.zone("split.horizontal", {
  pixy.segment("divider", function(ctx)
    return pixy.text("─", {fg = value(ctx, "active") == false and 237 or 1})
  end),
})

pixy.zone("pop.notify", {
  pixy.segment("message", function(ctx) return popup(ctx, true) end),
})

pixy.zone("pop.confirm", {
  pixy.segment("message", function(ctx) return popup(ctx, false) end),
})

pixy.zone("pop.choose", {
  pixy.segment("choices", chooser),
})

pixy.zone("oslo.direnv", {
  pixy.segment("report", direnv_report),
})
