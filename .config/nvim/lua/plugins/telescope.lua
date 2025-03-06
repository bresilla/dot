return {
    {
        'nvim-telescope/telescope.nvim', 
        tag = '0.1.8',
        config = function()
            local actions = require('telescope.actions')
            local sorters = require('telescope.sorters')

            require('telescope').setup{
                defaults = {
                    vimgrep_arguments = {
                        'rg',
                        '--color=never',
                        '--no-heading',
                        '--with-filename',
                        '--line-number',
                        '--column',
                        '--smart-case'
                    },
                    layout_config = {
                        prompt_position = "bottom",
                        width = 0.75,
                        preview_cutoff = 120,
                    },
                    prompt_prefix = ">>",
                    selection_strategy = "reset",
                    sorting_strategy = "descending",
                    layout_strategy = "horizontal",
                    -- shorten_path = true,
                    file_ignore_patterns = {"bash/*","resources/*"},
                    file_sorter =  require'telescope.sorters'.get_fuzzy_file,
                    color_devicons = true,
                    use_less = true,
                    mappings = {
                        i = {
                            ["<M-s>"] = actions.select_horizontal,
                            ["<M-v>"] = actions.select_vertical,
                            ["<CR>"] = actions.select_default + actions.center,
                        },
                        n = {
                            ["<esc>"] = actions.close
                        },
                    }
                },
            }

            center_list = require'telescope.themes'.get_dropdown({
                winblend = 10,
                width = 0.5,
                prompt = ">>",
                results_height = 6,
                previewer = false,
                mappings = {
                    i = {
                        ["<M-s>"] = actions.select_horizontal,
                        ["<M-v>"] = actions.select_vertical,
                        ["<CR>"] = actions.select_default + actions.center,
                    },
                    n = {
                        ["<esc>"] = actions.close
                    },
                }
            })

            vim.keymap.set(
                "n", "<leader>g", [[<cmd>lua require('telescope.builtin').live_grep()<cr>]],
                {silent = true, desc = "Live Grep" })
            vim.keymap.set(
                "n", "<leader>F", "<cmd>lua require('telescope.builtin').git_files()<cr>", 
                {silent = true, desc = "Git Files" })
            vim.keymap.set(
                "n", "<leader>f", [[<cmd>lua require('telescope.builtin').find_files()<cr>]], 
                {silent = true, desc = "Find Files" })
            vim.keymap.set(
                "n", "<leader>b", [[<cmd>lua require('telescope.builtin').buffers()<cr>]], 
                {silent = true, desc = "Buffers" })
            vim.keymap.set(
                "n", "<leader>e", [[<cmd>lua require("telescope").extensions.file_browser.file_browser()<cr>]],
                {silent = true, desc = "File Browser" })

        end,
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    {
        "nvim-telescope/telescope-file-browser.nvim",
        dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    }
}
