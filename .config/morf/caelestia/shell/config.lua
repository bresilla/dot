-- The shell's settings: defaults here, what differs in a JSON file under the
-- state directory, every value a signal (lib/settings.lua).
--
-- CAELESTIA_SETTINGS names another file (the tests point it at a scratch
-- one).

local morf = require("morf")
local settings = require("lib.util.settings")
local capture_tools={}
for _,tool in ipairs(require("lib.util.annotation").tools) do
  capture_tools[tool[1]]={color="#ef5350",width=tool[1]=="text" and 24 or 4,filled=false}
end

local path = (morf.env and morf.env("CAELESTIA_SETTINGS")) or morf.state_path("caelestia.json")

return settings.open {
  path = path,
  defaults = {
    theme = {
      -- What the Material scheme is built from: "lule" (the colour
      -- tool's accent -- lule, pywal), "wallpaper", a colour, or "auto"
      -- (lule when it has set anything, else the wallpaper). The tool's
      -- own colours are theme.lule either way.
      source = "auto",
      variant = "tonal_spot",
      mode = "dark",
    },
    appearance = {
      -- A font file every label is set in ("" for the installed faces).
      font_file = "",
      -- How big everything is drawn, from -1 (half the size) through 0 (the
      -- compositor's own scale) to 1 (twice it): the scale slider.
      zoom = 0,
    },
    wallpaper = {
      -- A picture to paint under everything; "" reads the path the
      -- caelestia tools keep in ~/.local/state/caelestia/wallpaper/path.txt.
      path = "",
      -- Whether the shell paints it at all. Off: the compositor's own
      -- wallpaper tool (hyprpaper, which lule drives) shows through, and
      -- the compositor has one full-screen layer fewer to blend on every
      -- redraw. The scheme follows the picture either way.
      draw = false,
    },
    bar = {
      workspaces = { shown = 5 },
      clock = { twelve_hour = true },
      -- What the Bluetooth popout's "Open settings" starts.
      bluetooth_settings = { "blueman-manager" },
    },
    dashboard = {
      -- Opens when the pointer reaches the top edge over it.
      hover = true,
    },
    sidebar = {
      -- Opens when the pointer reaches the middle of the right edge.
      hover = true,
    },
    -- Which pages each edge's panel holds (shell/pages.lua): a desk's right
    -- and left panels, and a phone's sheet from the top. A page moves by
    -- moving its key.
    panels = {
      right = { "settings", "notifications" },
      left = { "tasks", "calendar" },
      top = { "settings", "notifications", "tasks", "calendar", "assistant", "drop" },
    },
    leftbar = {
      -- Opens when the pointer reaches the left edge above the rail.
      hover = true,
    },
    bottom = {
      -- Opens the assistant workspace from the bottom edge.
      hover = true,
    },
    lule = {
      -- Empty follows LULE_W, then the current wallpaper's directory.
      folder = "",
      source = "generate",
      logo = "~/.dot/.bresilla/logo.svg",
      logo_size = 40,
    },
    capture = {
      -- Where screenshots and recordings go, both.
      folder = "~/Pictures/Captures",
      editor = true,
      tools = capture_tools,
      blur = 24, pixelate = 14, zoom = 2,
      cursor = false, save_dialog = false, copy_on_save = true, copy_to_disk = false,
      upload_endpoint = "https://litterbox.catbox.moe/resources/internals/api.php",
      hotkey = "Print", keybind_file = "",
      -- What each capture runs: `$FILE` is the file to write (in the
      -- folder, named for the time, with its extension), `~/` and `$HOME`
      -- expanded. An empty list runs nothing.
      commands = {
        screenshot_region = { "sh", "-c", "grim -g \"$(slurp)\" \"$0\" && wl-copy < \"$0\"", "$FILE.png" },
        screenshot_window = { "sh", "-c", "grim -g \"$(hyprctl -j activewindow | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\" \"$0\" && wl-copy < \"$0\"", "$FILE.png" },
        screenshot_screen = { "sh", "-c", "grim -o \"$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')\" \"$0\" && wl-copy < \"$0\"", "$FILE.png" },
        record_region = { "sh", "-c", "region=$(slurp -f '%wx%h+%x+%y') || exit; exec gpu-screen-recorder -w region -region \"$region\" -f 60 -o \"$0\"", "$FILE.mp4" },
        record_window = { "gpu-screen-recorder", "-w", "focused", "-f", "60", "-o", "$FILE.mp4" },
        record_screen = { "gpu-screen-recorder", "-w", "screen", "-f", "60", "-o", "$FILE.mp4" },
        open = { "xdg-open" },
      },
    },
    launcher = {
      max_shown = 7,
      action_prefix = ">",
    },
    rail = {
      -- The workspaces down the left edge.
      enabled = true,
      -- How long the numbered bud stays out after a switch, in ms.
      hold = 800,
    },
    -- The bar along an edge (bar.lua) -- not `bar`, the reference's settings.
    edgebar = {
      -- "on", "off", or "auto": up on narrow or portrait screens (a phone),
      -- down on a wide desk. The quick settings' Bar tile sets it.
      enabled = "auto",
      -- top, bottom, left or right.
      side = "top",
      -- "on" or "off": each window's title beside its icon, along a top or
      -- bottom bar.
      titles = "on",
    },
    -- Airplane mode, and what was on before it (to bring back).
    airplane = { on = false, was = { wifi = false, bluetooth = false, mobile = false } },
    -- sound, vibrate or silent (lib/ringer.lua; vibrate where feedbackd is).
    ringer = { mode = "sound" },
    -- The shell as the session's polkit agent (polkit.lua): "on", or "off"
    -- to leave the job to another (hyprpolkitagent, polkit-gnome).
    polkit = { agent = "on" },
    keyboard = {
      -- Up by itself when a program asks for text and no real keyboard
      -- is attached (a tablet, a detached keyboard); by hand either way.
      auto = true,
    },
    services = {
      weather_location = "",
      imperial = false,
    },
    utilities = {
      commands = {
        mic_on = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0" },
        mic_off = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1" },
        settings = {},
        -- Game mode on Hyprland: no animations, blur, gaps or rounding.
        gamemode_on = { "hyprctl", "--batch",
          "keyword animations:enabled 0; keyword decoration:blur:enabled 0; keyword general:gaps_in 0; keyword general:gaps_out 0; keyword decoration:rounding 0" },
        gamemode_off = { "hyprctl", "reload" },
      },
    },
    session = {
      -- What each of the session menu's actions runs (`$USER` is the
      -- user's name).
      commands = {
        logout = { "loginctl", "terminate-user", "$USER" },
        shutdown = { "systemctl", "poweroff" },
        hibernate = { "systemctl", "hibernate" },
        reboot = { "systemctl", "reboot" },
      },
    },
  },
}
