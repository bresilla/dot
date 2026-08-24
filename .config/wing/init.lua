-- wing's configuration. Loaded after every template manifest, so registering a name that already
-- exists replaces it rather than adding a second.
--
-- Templates are looked for in several roots, least specific first, and a later one wins:
--
--   <binary>/../share/wing/templates
--   <binary>/templates
--   ./templates
--   ~/.local/share/wing/templates
--   ~/.config/wing/templates          <- this directory, highest priority
--
-- So anything in ./templates beside this file overrides the copy that ships with wing.

local wing = require("wing")

-- Tokens replaced when a template is applied. A value is a string, or a function of the apply
-- context, which carries `template`, `flavour`, `name` and `path`.
--
-- wing.placeholders["{{author}}"] = "bresilla"
-- wing.placeholders["{{year}}"] = function() return os.date("%Y") end

-- Behaviour after a template is applied. Registered rather than assigned, so this file can hold as
-- many small named functions as it likes; one that raises is reported and the rest still run.
--
-- wing.on.apply(function(ctx)
--   os.execute("git -C " .. ctx.path .. " init -q")
-- end)

-- A template of your own is a directory under ./templates with its own template.lua. Overriding a
-- bundled one is registering its name again:
--
-- wing.template("go", { description = "my go starter", language = "go" })
