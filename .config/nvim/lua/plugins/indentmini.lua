return {
    {
        "nvimdev/indentmini.nvim",
        config = function()
            local indentmini = require("indentmini")
            indentmini.setup({
                char = "",
            })
        end,
    }
}