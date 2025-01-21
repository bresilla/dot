vim.keymap.set('n',            '<tab>',             [[:NvimTreeToggle<CR>]])

return {
    -- nvim tree
    {
        "nvim-tree/nvim-tree.lua",
        config = function()
            require("nvim-tree").setup({
                on_attach = function(bufnr)
                    local api = require("nvim-tree.api")
                    local function opts(desc)
                        return {
                            desc = "nvim-tree: " .. desc,
                            buffer = bufnr,
                            noremap = true,
                            silent = true,
                            nowait = true,
                        }
                    end
                    -- default mappings
                    api.config.mappings.default_on_attach(bufnr)
                    -- custom mappings
                    vim.keymap.set("n", '<tab>', api.tree.close,        opts("Close"))
                end,
                actions = {
                    open_file = {
                        quit_on_open = true,
                    },
                },
                sort = {
                    sorter = "case_sensitive",
                },
                view = {
                    width = 30,
                },
            })
        end,
    },
}
