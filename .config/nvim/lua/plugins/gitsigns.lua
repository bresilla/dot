return {
    {
        "lewis6991/gitsigns.nvim",
        event = "BufRead",
        config = function()
            local gitsigns = require("gitsigns")
            gitsigns.setup({
                signs_staged_enable = true,
                numhl = true,
                current_line_blame = true,
            })
        end,
    },
}