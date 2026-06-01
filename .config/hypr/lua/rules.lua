return function()
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
