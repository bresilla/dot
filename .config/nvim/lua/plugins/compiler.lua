-- vim.api.nvim_create_autocmd("LspAttach", {
--     group = vim.api.nvim_create_augroup("UserLspConfig", {}),
--     callback = function(args)
--         local client = vim.lsp.get_client_by_id(args.data.client_id)
--         if client.server_capabilities.inlayHintProvider then
--             vim.lsp.inlay_hint.enable(true, {bufnr = args.buf})
--         end
--     end
-- })

local function ToggleInlayHintsBuffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.lsp.inlay_hint.is_enabled({ bufnr }) then
    vim.lsp.inlay_hint.enable(false, { bufnr })
  else
    vim.lsp.inlay_hint.enable(true,  { bufnr })
  end
end
vim.keymap.set("n", "<leader>lp", ToggleInlayHintsBuffer, { desc = "Toggle LSP inlay hints"})

vim.api.nvim_create_user_command('DapSaveGDB', function()
  local path = '/tmp/gdb_breakpoints.gdb'
  local bps   = require('dap.breakpoints').get()
  local f, err = io.open(path, 'w')
  if not f then
    vim.notify('Error opening '..path..': '..err, vim.log.levels.ERROR)
    return
  end
  for buf, buf_bps in pairs(bps) do
    local filename = vim.api.nvim_buf_get_name(buf)
    for _, bp in ipairs(buf_bps) do
      if bp.condition and bp.condition ~= '' then
        f:write(string.format("break %s:%d if %s\n", filename, bp.line, bp.condition))
      else
        f:write(string.format("break %s:%d\n", filename, bp.line))
      end
    end
  end
  f:close()
  vim.notify('Breakpoints saved to '..path, vim.log.levels.INFO)
end, {
  desc = 'Dump all DAP breakpoints to /tmp/gdb_breakpoints.gdb',
})



-------------------------------------- LANGUAGE SERVERS

local lsps = {}

if vim.env.ENV == "pio" then
  table.insert(lsps, {
    "ccls",
    {
      init_options = {
        compilationDatabaseDirectory = "build",
        index = { threads = 0 },
        clang = { excludeArgs = { "-frounding-math" } },
      },
    },
  })
else
  table.insert(lsps, {
    "clangd",
    {
      cmd = { "clangd", "--header-insertion=never" },
    },
  })
end

table.insert(lsps, {
  "rust_analyzer",
  {
    settings = {
      ["rust-analyzer"] = {
        diagnostics = { enable = false },
      },
    },
  },
})

table.insert(lsps, {
  "qmlls",
  {
    cmd = { "qmlls6" },
  },
})

table.insert(lsps, {
  "pylsp",
  {
    settings = {
      pylsp = {
        plugins = {
          pycodestyle = {
            ignore = { "W391" },
            maxLineLength = 160,
          },
        },
      },
    },
  },
})

table.insert(lsps, { "lua_ls" })

for _, lsp in pairs(lsps) do
  local name, config = lsp[1], lsp[2]
  if config then
    vim.lsp.config(name, config)
  end
  vim.lsp.enable(name)
end

return {
    {
        "bresilla/lineslua.nvim",
        lazy = false,
        config = function()
            require("lsp_lines").setup({
                virtual_lines = {
                    only_current_line = true
                }
            })
        end
    },
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
}
