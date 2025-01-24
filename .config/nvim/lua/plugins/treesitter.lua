return {
    {
        'nvim-treesitter/nvim-treesitter',
        version = '*',
        config = function()
            tree = require('nvim-treesitter.configs')
            tree.setup {
                -- A list of parser names, or "all" (the listed parsers MUST always be installed)
                ensure_installed = { "c", "cpp", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline" },
                sync_install = false,
                auto_install = true,
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
        end,
    },
}