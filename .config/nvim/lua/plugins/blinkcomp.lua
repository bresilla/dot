return {
  {
    'saghen/blink.cmp',
    -- optional: provides snippets for the snippet source
    dependencies = {
        'rafamadriz/friendly-snippets',
        'echasnovski/mini.nvim'
    },
    version = '*',
    config = function()
      local blink = require('blink.cmp')
      blink.setup({
        keymap = { 
            preset = 'default',
            ['<Up>'] = { 'select_prev', 'fallback' },
            ['<Down>'] = { 'select_next', 'fallback' },
            ['<Tab>'] = {
                function(cmp)
                  if cmp.snippet_active() then return cmp.accept()
                  else return cmp.select_and_accept() end
                end,
                'snippet_forward',
                'fallback'
            },
        },
        appearance = {
            use_nvim_cmp_as_default = true,
            nerd_font_variant = 'mono'
        },
        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer' },
        },
        completion = { 
            menu = { 
                auto_show = function(ctx)
                    return ctx.mode ~= 'cmdline' 
                end,
                draw = {
                    treesitter = { "lsp" },
                    columns = {
                      { "kind_icon" , gap = 2},
                      { "label", "label_description", gap = 1 },
                    },
                },
            },
            ghost_text = { 
                enabled = true 
            },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200,
            },
            list = {
                selection = {
                    preselect = function(ctx)
                      return ctx.mode ~= 'cmdline' and not require('blink.cmp').snippet_active({ direction = 1 })
                    end,
                    auto_insert = function(ctx) return ctx.mode ~= 'cmdline' end,
                },
            },
        },
      })
    end,
    -- opts = {
    --   keymap = { preset = 'default' },
    --   appearance = {
    --     use_nvim_cmp_as_default = true,
    --     nerd_font_variant = 'mono'
    --   },
    --   sources = {
    --     default = { 'lsp', 'path', 'snippets', 'buffer' },
    --   },
    --   completion = { 
    --     menu = { 
    --         auto_show = { function(ctx) return ctx.mode ~= 'cmdline' end },
    --         ghost_text = { enabled = true },
    --     }
    --   }
    -- },
    -- opts_extend = { "sources.default" }
  }
}