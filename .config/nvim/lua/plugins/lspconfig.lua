return {{
    'neovim/nvim-lspconfig',
    config = function()
        local lspconfig = require('lspconfig')
        -- lsp for c and cpp
        if vim.env.ENV == "pio" then
            -- works with platformio and microcontroller projects
            require('lspconfig').ccls.setup {
                init_options = {
                    compilationDatabaseDirectory = "build",
                    index = {
                        threads = 0
                    },
                    clang = {
                        excludeArgs = {"-frounding-math"}
                    }
                }
            }
        else
            -- works with normal c and cpp projects
            require('lspconfig').clangd.setup {}
        end
        -- lsp for rust
        lspconfig.rust_analyzer.setup {
            settings = {
                ['rust-analyzer'] = {
                    diagnostics = {
                        enable = false
                    }
                }
            }
        }
        -- lsp for python
        lspconfig.pylsp.setup{
            settings = {
                pylsp = {
                plugins = {
                    pycodestyle = {
                    ignore = {'W391'},
                    maxLineLength = 160
                    }
                }
                }
            }
        }
            -- lspconfig.pylyzer.setup {}
        -- lsp for lua
        lspconfig.lua_ls.setup {}
    end,
    dependencies = {
        {
            "folke/lazydev.nvim",
            ft = "lua", -- only load on lua files
            opts = {
              library = {
                -- See the configuration section for more details
                -- Load luvit types when the `vim.uv` word is found
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
              },
            },
          },
    }
}, {
    "bresilla/lineslua.nvim",
    lazy = false,
    config = function()
        require("lsp_lines").setup({
            virtual_lines = {
                only_current_line = true
            }
        })
    end
}}
