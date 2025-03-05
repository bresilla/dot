-- local signs = {
--     Error = "-",
--     Warn = "-",
--     Hint = "-",
--     Info = "-"
-- }
-- for type, icon in pairs(signs) do
--     local hl = "DiagnosticSign" .. type
--     vim.fn.sign_define(hl, {
--         text = icon,
--         texthl = hl,
--         numhl = hl
--     })
-- end

-- Autocommand to force diagnostics to refresh on every cursor movement
vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
    callback = function()
        -- Hide current diagnostics
        vim.diagnostic.hide(nil, 0)
        -- Then show them again, causing a redraw
        vim.diagnostic.show(nil, 0)
    end
})

vim.diagnostic.config({
    virtual_lines = {
        only_current_line = true
    },
    virtual_text = {
        format = function(diagnostic)
            local diags = vim.diagnostic.get(diagnostic.bufnr, {
                lnum = diagnostic.lnum
            })
            local cursor_pos = vim.api.nvim_win_get_cursor(0)
            local cursor_line = cursor_pos[1] - 1 -- convert to 0-based

            if (cursor_line ~= diagnostic.lnum) or (vim.api.nvim_get_mode().mode == "v") then
                local win_width = vim.api.nvim_win_get_width(0)-1
                local text_length = #(vim.api.nvim_get_current_line())
                local diag_msg = diagnostic.message
                if #(diag_msg) > math.floor(0.20 * win_width) then
                    diag_msg = diag_msg:sub(0, math.floor(0.20 * win_width) - #("...")) .. "..."
                end
                diag_msg = " " .. diag_msg
                for i = 1, #diags do
                    diag_msg = "■" .. diag_msg
                end
                return diag_msg
            end
            return "[" .. tostring(#diags) .. "]"
        end,
        prefix = "",
        severity_sort = true,
        virt_text_pos = "right_align",
        suffix = " <<",
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = '>>',
            [vim.diagnostic.severity.WARN] = '>>',
            [vim.diagnostic.severity.INFO] = '>>',
            [vim.diagnostic.severity.HINT] = '>>',
        },
    },
    underline = true,
    float = {
        source = "none"
    }
})
