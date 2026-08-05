-- oslo configuration. Lua, and the only config file the shell reads.

-- No version banner or exit hint at startup.
oslo.misc.welcome = false

-- vi key bindings while editing a line. Off by default since oslo 0.2.5.
oslo.vi.enabled = true

-- Aliases, shared with every other shell on this machine. `oslo.source` runs the file *in this
-- shell*, so its aliases and functions stick — unlike `oslo.run`, which would run it in a child
-- that then exits with everything it defined.
--
-- `~/.profile` is deliberately absent: a *login* shell reads `/etc/profile` and then `~/.profile`
-- on its own, as every shell does. Sourcing it here as well would run it twice in the session
-- that already had it. Aliases are here rather than there because `.profile` is read once at
-- login and aliases are not exported, so every later shell needs its own copy.
oslo.source(oslo.env.get("HOME") .. "/.config/profile/aliases.sh")
