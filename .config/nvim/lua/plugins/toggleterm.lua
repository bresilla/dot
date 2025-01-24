return{    
    {
        -- amongst your other plugins
        'akinsho/toggleterm.nvim', 
        version = "*", 
        config = function()
            local term = require("toggleterm")
            term.setup({
            })
        end,
    },
}