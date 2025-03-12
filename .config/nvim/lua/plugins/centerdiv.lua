return {
    {
        "shortcuts/no-neck-pain.nvim",
        config = function()
            require("no-neck-pain").setup({
                width = 150,
                    buffers = {
                    blend = -0.5,
                },
                 integrations = { NvimTree = { reopen = true } },
            })
        end,
    },
}
