vim.keymap.set('n',            '<tab>',             [[:NvimTreeToggle<CR>]])

return {
    -- nvim tree
    {
        "nvim-tree/nvim-tree.lua",
        version = "1.10.0",
        config = function()
            local nvimtree = require('nvim-tree')
            nvimtree.setup({
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
                hijack_cursor = true,
                actions = {
                    open_file = {
                        quit_on_open = true,
                    },
                },
                renderer = {
                    root_folder_label = false,
                    indent_width = 1,
                    icons = {
                        show = {
                            file = true,
                            folder = true,
                            folder_arrow = true,
                            git = false,
                            modified = false,
                            hidden = false,
                            diagnostics = false,
                            bookmarks = false,
                        },
                    },
                },
                sort = {
                    sorter = "case_sensitive",
                },
                view = {
                    width = 30,
                    signcolumn = "no",
                },
            })
        end,
    },
}
