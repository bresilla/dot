return function()
    local function scratchpad_rule(name, title)
        hl.window_rule({
            name = name,
            match = { title = title },
            float = true,
        })
    end

    scratchpad_rule("scratchpad_ask", "ask")
    scratchpad_rule("scratchpad_browsy", "browsy")
    scratchpad_rule("scratchpad_appy", "appy")
    scratchpad_rule("scratchpad_noteing", "noteing")
    scratchpad_rule("scratchpad_main", "main")

    hl.window_rule({
        name = "note_terminal",
        match = { title = "note" },
        float = true,
    })

    hl.window_rule({
        name = "main_terminal",
        match = { title = "main" },
        float = true,
    })

    hl.window_rule({
        name = "spotify",
        match = { class = [[\b[Ss]potify\b]] },
        float = true,
    })

    hl.window_rule({
        name = "astrocraft",
        match = { title = "astrocraft" },
        float = true,
    })

    hl.window_rule({ match = { class = ".*float.*" }, float = true })
    hl.window_rule({ match = { class = ".*mpv.*" }, float = true })
    hl.window_rule({ match = { class = ".*scrcpy.*" }, float = true })
    hl.window_rule({ match = { class = ".*matplotlib.*" }, float = true })
    hl.window_rule({ match = { class = ".*opencv.*" }, float = true })
    hl.window_rule({ match = { class = ".*Spotify.*" }, float = true })
end
