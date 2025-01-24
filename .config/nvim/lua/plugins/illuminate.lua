-- Define a Lua function to conditionally handle the 'n' key press
-- This function will check if there's an active search pattern
-- If there's no active search pattern, it will set one using the current word under the cursor
local function conditional_search_next()
    local search_pattern = vim.fn.getreg('/')
    if search_pattern == "" then
        local current_word = vim.fn.expand('<cword>')
        local escaped_word = vim.fn.escape(current_word, '\\/.*[]~$^')
        vim.fn.setreg('/', '\\<' .. escaped_word .. '\\>')
        vim.o.hlsearch = true
        vim.cmd('normal! n')
    else    
        vim.cmd('normal! n')
    end
end

vim.keymap.set('n', 'n', conditional_search_next, { noremap = true, silent = true })
      

return {
    {
        "danielosw/nvim-illuminate",
        event = "BufRead",
        config = function()
            local illuminate = require("illuminate")
            illuminate.configure({
                providers = {
                    'lsp',
                    'treesitter',
                    'regex',
                },
            })
        end,
    },
}