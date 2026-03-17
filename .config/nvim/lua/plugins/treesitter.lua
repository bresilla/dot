return {
    {
        'nvim-treesitter/nvim-treesitter',
        version = '*',
        config = function()
            local fol_tree_root = '/tmp/fol'
            local fol_tree_parser = fol_tree_root .. '/src/parser.c'
            local parsers = require('nvim-treesitter.parsers')
            local install = require('nvim-treesitter.install')
            local parser_config = parsers.get_parser_configs()

            local function ensure_fol_tree_bundle()
                if vim.fn.filereadable(fol_tree_parser) == 1 then
                    return true
                end

                vim.fn.mkdir(fol_tree_root, 'p')
                local result = vim.system(
                    { 'fol', 'tool', 'tree', 'generate', fol_tree_root },
                    { text = true }
                ):wait()

                if result.code ~= 0 then
                    local message = result.stderr
                    if message == nil or message == '' then
                        message = result.stdout
                    end
                    if message == nil or message == '' then
                        message = 'unknown tree-sitter generation failure'
                    end
                    vim.notify(
                        'Failed to generate the FOL tree-sitter bundle:\n' .. message,
                        vim.log.levels.ERROR
                    )
                    return false
                end

                return vim.fn.filereadable(fol_tree_parser) == 1
            end

            local function install_command(command_name, opts)
                local command = install.commands[command_name]
                local runner = opts.bang and command['run!'] or command.run
                runner(unpack(opts.fargs))
            end

            local function wrap_fol_install(command_name, user_command_name)
                vim.api.nvim_create_user_command(user_command_name, function(opts)
                    for _, lang in ipairs(opts.fargs) do
                        if lang == 'fol' and not ensure_fol_tree_bundle() then
                            return
                        end
                    end
                    install_command(command_name, opts)
                end, {
                    bang = true,
                    nargs = '+',
                    complete = 'custom,nvim_treesitter#installable_parsers',
                    force = true,
                })
            end

            parser_config.fol = {
                install_info = {
                    url = fol_tree_root,
                    files = { 'src/parser.c' },
                    generate_requires_npm = false,
                    requires_generate_from_grammar = false,
                },
                filetype = 'fol',
            }

            local tree = require('nvim-treesitter.configs')
            tree.setup {
                -- A list of parser names, or "all" (the listed parsers MUST always be installed)
                ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
                sync_install = false,
                auto_install = false,
                ignore_install = { "javascript" },              
                -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!
                highlight = {
                  enable = true,
                  -- disable files biger than 200kb
                  disable = function(lang, buf)
                      local max_filesize = 200 * 1024 -- 200 KB
                      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                      if ok and stats and stats.size > max_filesize then
                          return true
                      end
                  end,
                  additional_vim_regex_highlighting = false,
                },
              }

            wrap_fol_install('TSInstall', 'TSInstall')
            wrap_fol_install('TSInstallSync', 'TSInstallSync')

            if not parsers.has_parser('fol') and ensure_fol_tree_bundle() then
                install.commands.TSInstallSync.run('fol')
            end
        end,
    },
}
