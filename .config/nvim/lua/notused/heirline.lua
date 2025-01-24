return{
    {
        "rebelot/heirline.nvim",
        config = function()
            local heirline = require("heirline")
            local StatusLine = {
                {...}, {...}, {..., {...}, {...}, {..., {...}, {..., {...}}}}
            }
                
            local WinBar = {{...}, {{...}, {...}}}
                
            local TabLine = {{...}, {...}, {...}}

            heirline.setup({
                statusline = StatusLine,
                winbar = WinBar,
                tabline = TabLine,
            })
        end
    },
}