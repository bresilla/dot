return {
    {
        'nvim-treesitter/nvim-treesitter',
        version = '*',
        config = function()
            local cache_home = vim.env.XDG_CACHE_HOME
            if not cache_home or cache_home == '' then
                cache_home = vim.fn.expand('~/.cache')
            end
            local fol_tree_root = cache_home .. '/fol'
            local fol_tree_parser = fol_tree_root .. '/src/parser.c'
            local parsers = require('nvim-treesitter.parsers')
            local install = require('nvim-treesitter.install')
            local parser_config = parsers.get_parser_configs()

            -- Path of the installed, compiled parser (if any) on the runtimepath.
            local function installed_parser_path()
                return vim.api.nvim_get_runtime_file('parser/fol.so', false)[1]
            end

            -- mtime (seconds) of the `fol` executable, or nil if unavailable.
            local function fol_binary_mtime()
                local exe = vim.fn.exepath('fol')
                if exe == '' then
                    return nil
                end
                local st = vim.loop.fs_stat(exe)
                return st and st.mtime.sec or nil
            end

            -- The compiled parser is stale when the `fol` binary is newer than
            -- the installed `fol.so` (the grammar may have changed). Also stale
            -- when no parser is installed yet.
            local function fol_parser_is_stale()
                local binary_mtime = fol_binary_mtime()
                if not binary_mtime then
                    return false
                end
                local parser = installed_parser_path()
                if not parser then
                    return true
                end
                local st = vim.loop.fs_stat(parser)
                if not st then
                    return true
                end
                return binary_mtime > st.mtime.sec
            end

            local function ensure_fol_tree_bundle(force)
                if vim.fn.executable('fol') ~= 1 then
                    return false
                end

                if not force and vim.fn.filereadable(fol_tree_parser) == 1 then
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

            -- Keep the FOL grammar in sync with the current `fol` binary:
            --   * regenerate the cached bundle when the parser is stale (the fol
            --     binary is newer than the compiled parser) or missing,
            --   * expose queries/fol/*.scm via the runtimepath so tree-sitter
            --     highlighting, locals, and symbols resolve (without this the
            --     parser compiles and files parse, but no colors show),
            --   * force-recompile the parser whenever it is stale or missing.
            local fol_stale = fol_parser_is_stale()
            if ensure_fol_tree_bundle(fol_stale) then
                vim.opt.runtimepath:append(fol_tree_root)
                if fol_stale or not parsers.has_parser('fol') then
                    install.commands.TSInstallSync['run!']('fol')
                end
            end
        end,
    },
}
