return{
    {
        'azorng/goose.nvim',
        branch = 'main',
        config = function()
                -- Default configuration with all available options
            require('goose').setup({
                keymap = {
                    global = {
                        open_input = '<leader>gi',             -- Opens and focuses on input window on insert mode
                        open_output = '<leader>go',            -- Opens and focuses on output window 
                        close = '<leader>gq',                  -- Close UI windows
                        toggle_fullscreen = '<leader>gf',      -- Toggle between normal and fullscreen mode
                        select_session = '<leader>gs',         -- Select and load a goose session
                    },
                    window = {
                        submit = '<cr>',                     -- Submit prompt
                        close = '<esc>',                     -- Close UI windows
                        stop = '<C-c>',                      -- Stop a running job
                        next_message = ']]',                 -- Navigate to next message in the conversation
                        prev_message = '[[',                 -- Navigate to previous message in the conversation
                        mention_file = '@',                  -- Pick a file and add to context. See File Mentions section
                        toggle_pane = '<C-n>'                -- Toggle between input and output panes
                    }
                },
                ui = {
                    window_width = 0.6,                    -- Width as percentage of editor width
                    input_height = 0.15,                   -- Input height as percentage of window height
                    fullscreen = false,                    -- Start in fullscreen mode (default: false)
                    layout = "center",                     -- Layout of UI window (default: "floating")
                    floating_height = 0.85,                -- Floating window height as percentage of editor height
                }
            })
        end,
     }
}
