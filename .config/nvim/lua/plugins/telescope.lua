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
        end,
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    {
        "nvim-telescope/telescope-file-browser.nvim",
        dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    }
}
