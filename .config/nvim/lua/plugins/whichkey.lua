return{
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        keys = {
          {
            "<leader>?",
            function()
              require("which-key").show({ global = false })
            end,
            desc = "Buffer Local Keymaps (which-key)",
          },
        },
        config = function()
            local wk = require("which-key")
            wk.setup {
                plugins = {
                    marks = true, -- shows a list of your marks on ' and `
                    registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
                    -- the presets plugin, adds help for a bunch of default keybindings in Neovim
                    -- No actual key bindings are created
                    presets = {
                        operators = true, -- adds help for operators like d, y, ... and registers them for motion / text object completion
                        motions = true, -- adds help for motions
                        text_objects = true, -- help for text objects triggered after entering an operator
                        windows = true, -- default bindings on <c-w>
                        nav = true, -- misc bindings to work with windows
                        z = true, -- bindings for folds, spelling and others prefixed with z
                        g = true, -- bindings for prefixed with g
                    },
                },
                -- operators = { gc = "Comments" },
                icons = {
                    mappings = false, -- shows the icon on the popup that appears when you press on the command line
                    breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
                    separator = "➜", -- symbol used between a key and it's label
                    group = "+", -- symbol prepended to a group
                },
                -- window = {
                --     border = "none", -- none, single, double, shadow
                --     position = "bottom", -- bottom, top
                --     margin = { 1, 0, 1, 0 }, -- extra window margin [top, right, bottom, left]
                --     padding = { 2, 2, 2, 2 }, -- extra window padding [top, right, bottom, left]
                -- },
                layout = {
                    height = { min = 4, max = 25 }, -- min and max height of the columns
                    width = { min = 20, max = 50 }, -- min and max width of the columns
                    spacing = 3, -- spacing between columns
                },
                -- hidden = { "<silent>", "<cmd>", "<Cmd>", "<CR>", "call", "lua", "^:", "^ "}, -- hide mapping boilerplate
                show_help = true, -- show help message on the command line when the popup is visible
                -- triggers = "auto", -- automatically setup triggers
            }

            wk.add({
                { "<leader>c", group = "ChatGPT"},
                { "<leader>cc", "<cmd>ChatGPT<CR>", desc = "ChatGPT", mode = { "n", "v" } },
                { "<leader>ce", "<cmd>ChatGPTEditWithInstruction<CR>", desc = "Edit with instruction", mode = { "n", "v" } },
                { "<leader>cg", "<cmd>ChatGPTRun grammar_correction<CR>", desc = "Grammar Correction", mode = { "n", "v" } },
                { "<leader>ct", "<cmd>ChatGPTRun translate<CR>", desc = "Translate", mode = { "n", "v" } },
                { "<leader>ck", "<cmd>ChatGPTRun keywords<CR>", desc = "Keywords", mode = { "n", "v" } },
                { "<leader>cd", "<cmd>ChatGPTRun docstring<CR>", desc = "Docstring", mode = { "n", "v" } },
                { "<leader>ca", "<cmd>ChatGPTRun add_tests<CR>", desc = "Add Tests", mode = { "n", "v" } },
                { "<leader>co", "<cmd>ChatGPTRun optimize_code<CR>", desc = "Optimize Code", mode = { "n", "v" } },
                { "<leader>cs", "<cmd>ChatGPTRun summarize<CR>", desc = "Summarize", mode = { "n", "v" } },
                { "<leader>cf", "<cmd>ChatGPTRun fix_bugs<CR>", desc = "Fix Bugs", mode = { "n", "v" } },
                { "<leader>cx", "<cmd>ChatGPTRun explain_code<CR>", desc = "Explain Code", mode = { "n", "v" } },
                { "<leader>cr", "<cmd>ChatGPTRun roxygen_edit<CR>", desc = "Roxygen Edit", mode = { "n", "v" } },
                { "<leader>cl", "<cmd>ChatGPTRun code_readability_analysis<CR>", desc = "Code Readability Analysis", mode = { "n", "v" } },
            })

            wk.add({
                { "<leader>l", group = "LSP"},
                { "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<CR>", desc = "Rename", mode = { "n", "v" } },
                { "<leader>ls", "<cmd>lua vim.lsp.buf.signature_help()<CR>", desc = "Signature Help", mode = { "n", "v" } },
                { "<leader>lc", "<cmd>lua vim.lsp.buf.code_action()<CR>", desc = "Code Action", mode = { "n", "v" } },
                { "<leader>lf", "<cmd>lua vim.lsp.buf.formatting()<CR>", desc = "Formatting", mode = { "n", "v" } },
                { "<leader>lh", "<cmd>lua vim.lsp.buf.hover()<CR>", desc = "Hover", mode = { "n", "v" } },
                { "<leader>lt", "<cmd>lua require('telescope.builtin').lsp_type_definitions()<cr>", desc = "Type Definitions", mode = { "n", "v" } },
                { "<leader>ll", "<cmd>lua require('telescope.builtin').lsp_references()<cr>", desc = "References", mode = { "n", "v" } },
                { "<leader>li", "<cmd>lua require('telescope.builtin').lsp_implementations()<cr>", desc = "Implementations", mode = { "n", "v" } },
                { "<leader>ld", "<cmd>lua require('telescope.builtin').diagnostics()<cr>", desc = "Diagnostics", mode = { "n", "v" } },
            })

            wk.add({
                { "<leader>g", group = "Goose"},
                -- check goose.lua for configuration
                })

            -- TELESCOPE
            wk.add({
                { "<leader>r", "<cmd>lua require('telescope.builtin').live_grep()<cr>", desc = "Rip Grep", mode = { "n", "v" } },
                { "<leader>F", "<cmd>lua require('telescope.builtin').git_files()<cr>", desc = "Git Files", mode = { "n", "v" } },
                { "<leader>f", "<cmd>lua require('telescope.builtin').find_files()<cr>", desc = "Find Files", mode = { "n", "v" } },
                { "<leader>b", "<cmd>lua require('telescope.builtin').buffers()<cr>", desc = "Buffers", mode = { "n", "v" } },
                { "<leader>e", ":Telescope file_browser<CR>", desc = "File Browser", mode = { "n", "v" } },
            })
        end,
    }
}
