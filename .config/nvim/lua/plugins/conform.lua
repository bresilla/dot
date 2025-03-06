-- vim.api.nvim_create_autocmd("BufWritePre", {
--     pattern = "*",
--     callback = function(args)
--       require("conform").format({ bufnr = args.buf })
--     end,
-- })

return {
    {
        'stevearc/conform.nvim',
        config = function()
            local conform = require('conform')
            conform.setup({
                formatters_by_ft = {
                    c = { 'clang-format' },
                    cpp = { 'clang-format' },
                    rust = { 'rustfmt' },
                    zig = { 'zig fmt' },
                    python = { 'black' },
                }
            })

            vim.api.nvim_create_autocmd("BufWritePre", {
                pattern = "*",
                callback = function(args)
                    require("conform").format({ bufnr = args.buf })
                end,
            })

            vim.keymap.set(
                "n", '<space>lf', [[<CMD>lua require("conform").format()<CR>]], 
                {noremap = true, silent = true, desc = "Format" }
            )
        end,
    },
}
