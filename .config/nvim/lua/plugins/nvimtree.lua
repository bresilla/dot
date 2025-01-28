vim.keymap.set('n',            '<tab>',             [[:NvimTreeToggle<CR>]], { noremap = true, silent = true })

return {
    {
        "nvim-tree/nvim-tree.lua",
        version = "1.10.0",
        config = function()
            local nvimtree = require('nvim-tree')
            local api = require("nvim-tree.api")

            nvimtree.setup({
                on_attach = function(bufnr)
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
                    vim.keymap.set("n", '<tab>', api.tree.close,  opts("Close"))
                end,
                hijack_cursor = true,
                actions = {
                    open_file = {
                        quit_on_open = true,
                    },
                },
                renderer = {
                    root_folder_label = false,
                    indent_width = 3,
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
                        padding = " ", -- padding between icon and filename
                        glyphs = {
                            default = "",
                            symlink = "",
                            bookmark = "󰆤",
                            modified = "●",
                            hidden = "󰜌",
                            folder = {
                              arrow_closed = "",
                              arrow_open = "",
                              default = "",
                              open = "",
                              empty = "",
                              empty_open = "",
                              symlink = "",
                              symlink_open = "",
                            },
                            git = {
                              unstaged = "✗",
                              staged = "✓",
                              unmerged = "",
                              renamed = "➜",
                              untracked = "★",
                              deleted = "",
                              ignored = "◌",
                            },
                        },
                    },
                    indent_markers = {
                        enable = true,
                        inline_arrows = true,
                        icons = {
                          corner = "└",
                          edge   = "│",
                          item   = "├",
                          bottom = "─",
                          none   = " ",
                        },
                      },
                },
                sort = {
                    sorter = "case_sensitive",
                },
                view = {
                    width = {
                        min = 40,
                        max = 40,
                        padding = 1, -- padding on the right
                    },
                    signcolumn = "no",
                },
            })
        end,
    },
}
