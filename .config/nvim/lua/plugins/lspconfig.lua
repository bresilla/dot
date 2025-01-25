vim.diagnostic.config({
    virtual_text = {
      format = function(diagnostic)
        local lines = vim.split(diagnostic.message, '\n')
        local win_width = vim.api.nvim_win_get_width(0)
        if #lines == 0 or win_width < 50 then return nil end

        local last = lines[1]
        local diag_msg = string.format("× %s", last:gsub("\r", ""):gsub("\n", "  "))
        local diag_length = #(diag_msg)
        local text_length = #(vim.api.nvim_get_current_line())
        local get_highlight = vim.lsp.diagnostic._get_severity_highlight_name
        local three_dots = "..."

        cut_text = math.floor(0.25 * win_width)

        if diag_length > cut_text then
            diag_length = cut_text
            diag_msg = diag_msg:sub(0, diag_length - #three_dots) .. three_dots
        end

        if text_length > math.floor(0.75 * win_width) then
            diag_msg = diag_msg:sub(0, win_width - text_length - #lines - 8 - #three_dots) .. three_dots
        end

        local virt_texts = string.rep("━", win_width - diag_length - #lines - text_length - 7)
        for i = 1, #lines do
            virt_texts = virt_texts .. "×"
        end
        virt_texts = virt_texts .. " " .. diag_msg
        return virt_texts
      end,
      suffix = '>',
    },
})


vim.diagnostic.config({
    virtual_text = {
      format = function(diagnostic)
        local lines = vim.split(diagnostic.message, '\n')
        return lines[1]
      end,
      prefix = '●', -- Could be '■', '▎', 'x'
      severity_sort = true,
      virt_text_pos = 'right_align',
      suffix = '  -',
    },
    float = {
      source = 'always',
    },
})

local signs = { 
    Error = "-", 
    Warn =  "-",
    Hint =  "-",
    Info =  "-", 
}
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

vim.api.nvim_create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
        local opts = {
            focusable = false,
            close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
            border = 'none',
            source = 'always',
            prefix = ' ',
            scope = 'cursor',
          }
        vim.diagnostic.open_float(nil, opts)
    end
})

return {
    {
        'neovim/nvim-lspconfig',
        config = function()
            local lspconfig = require('lspconfig')
            lspconfig.clangd.setup{}
        end
    },
}