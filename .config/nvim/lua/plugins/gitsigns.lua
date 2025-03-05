return {
    {
        "lewis6991/gitsigns.nvim",
        event = "BufRead",
        dependencies = {
            "sindrets/diffview.nvim",
        },
        config = function()
            local gitsigns = require("gitsigns")
            gitsigns.setup({
                signs_staged_enable = true,
                numhl = true,
                current_line_blame = true,
                current_line_blame_opts = {
                    virt_text = true,
                    virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
                    delay = 1000,
                    ignore_whitespace = false,
                    virt_text_priority = 100,
                    use_focus = true,
                },
                  signs = {
                    add          = { text = '┃' },
                    change       = { text = '┃' },
                    delete       = { text = '.' },
                    topdelete    = { text = '.' },
                    changedelete = { text = '┆' },
                    untracked    = { text = '¦' },
                },
                current_line_blame_formatter = '     -■-  <author>, <author_time:%R>',
            })
        end,
    },
}
