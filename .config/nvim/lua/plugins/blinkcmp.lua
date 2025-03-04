local function lspkind_config()
    local lspKindConfig = require("lspkind")
    local pre = "|"
    local post = "|"
    lspKindConfig.init({
        symbol_map = {
            Copilot =       pre .. "" .. post,
            Text =          pre .. "󰦨" .. post,
            Boolean =       pre .. "" .. post,
            Character =     pre .. "󱄽" .. post,
            Class =         pre .. "" .. post,
            Color =         pre .. "" .. post,
            Constant =      pre .. "" .. post,
            Constructor =   pre .. "" .. post,
            Enum =          pre .. "" .. post,
            EnumMember =    pre .. "" .. post,
            Event =         pre .. "" .. post,
            Field =         pre .. "" .. post,
            File =          pre .. "" .. post,
            Folder =        pre .. "" .. post,
            Function =      pre .. "󰊕" .. post,
            Interface =     pre .. "" .. post,
            Keyword =       pre .. "" .. post,
            Method =        pre .. "" .. post,
            Module =        pre .. "" .. post,
            Number =        pre .. "" .. post,
            Operator =      pre .. "" .. post,
            Parameter =     pre .. "" .. post,
            Property =      pre .. "" .. post,
            Reference =     pre .. "󰌹" .. post,
            Snippet =       pre .. "" .. post,
            String =        pre .. "" .. post,
            Struct =        pre .. "" .. post,
            TypeParameter = pre .. "" .. post,
            Unit =          pre .. "" .. post,
            Value =         pre .. "" .. post,
            Variable =      pre .. "" .. post
        }
    })
end

return {{
    'saghen/blink.cmp',
    -- optional: provides snippets for the snippet source
    dependencies = {
        { "saghen/blink.compat",
            optional = false,
            version = "*",
        },
        { "onsails/lspkind.nvim",
            config = lspkind_config
        },
    },
    version = '*',
    config = function()
        local blink = require('blink.cmp')
        blink.setup({
            keymap = {
                preset = 'default',
                ['<Up>'] = {'select_prev', 'fallback'},
                ['<Down>'] = {'select_next', 'fallback'},
                ['<CR>'] = {'accept', 'fallback'},
                -- ['<Tab>'] = {function(cmp)
                --     if cmp.snippet_active() then
                --         return cmp.accept()
                --     else
                --         return cmp.select_and_accept()
                --     end
                -- end, 'snippet_forward', 'fallback'}
            },
            appearance = {
                use_nvim_cmp_as_default = true,
                nerd_font_variant = 'mono'
            },
            sources = {
                -- providers = {
                --     copilot = {
                --         name = "copilot",
                --         module = "blink-cmp-copilot",
                --         score_offset = 100,
                --         async = true
                --     }
                -- },
                default = {'lsp', 'path', 'buffer'},
            },
            completion = {
                trigger = {
                    -- show_on_keyword = false,
                    show_on_trigger_character = true,
                    show_on_insert_on_trigger_character = true,
                },
                menu = {
                    auto_show = function(ctx)
                        return ctx.mode ~= 'cmdline' 
                    end,
                    draw = {
                        treesitter = {
                            "lsp"
                        },
                        padding = 0,
                        columns = {
                            { "kind_icon" },
                            { "label", "label_description", gap = 1 }
                        },
                        components = {
                            kind_icon = {
                                text = function(ctx)
                                    return require("lspkind").symbolic(ctx.kind, {
                                        mode = "symbol",
                                        preset = "codicons"
                                    })
                                end
                            },
                            -- kind = {
                            --     highlight = function(ctx) 
                            --         return { 
                            --             { -1, 1 + #ctx.icon_gap + 1, group = 'BlinkCmpKind' .. ctx.kind } 
                            --         } 
                            --     end,
                            -- },
                            label = {
                                width = { fill = false, max = 60 },
                                ellipsis = true,
                            },
                        }
                    },
                    scrollbar = false,
                },
                ghost_text = {
                    enabled = false,
                },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 200,
                    window = {
                        scrollbar = false,
                    },
                },
                list = {
                    selection = {
                        preselect = false,
                        auto_insert = true,
                    },
                }
            },
            signature = {
                enabled = true,
            },
        })
    end
}}
