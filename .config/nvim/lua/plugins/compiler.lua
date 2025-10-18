return {
    {
        "bresilla/lineslua.nvim",
        lazy = false,
        config = function()
            require("lsp_lines").setup({
                virtual_lines = {
                    only_current_line = true
                }
            })
        end
    },
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
}
