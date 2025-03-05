return {
    {
        "petertriho/nvim-scrollbar",
        dependencies = {
            "kevinhwang91/nvim-hlslens",
        },
        config = function()
            local scrollbar = require("scrollbar")
            scrollbar.setup({
                handlers = {
                    cursor = false,
                    diagnostic = false,
                    gitsigns = false, -- Requires gitsigns
                    handle = true,
                    search = true, -- Requires hlslens
                },
                marks = {
                    Search = {
                        text = { ".", "." },
                        priority = 1,
                        highlight = "Search",
                    },
                },
            })
            require("scrollbar.handlers.search").setup({})
        end
    }
}
