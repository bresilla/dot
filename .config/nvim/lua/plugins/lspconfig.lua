return {
  "neovim/nvim-lspconfig",
  config = function()
    -- Client-side command a code lens can trigger: run the FOL package.
    vim.lsp.commands = vim.lsp.commands or {}
    vim.lsp.commands["fol.run"] = function(command)
      local file = command.arguments and command.arguments[1]
      local dir = file and vim.fn.fnamemodify(file, ":h") or vim.fn.getcwd()
      vim.cmd("botright 12split | terminal cd " .. vim.fn.fnameescape(dir) .. " && fol code run")
    end

    -- Enable inlay hints, code lens, and LSP folding when a capable server attaches.
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return
        end
        local buf = args.buf
        if client.server_capabilities.inlayHintProvider and client.name ~= "clangd" then
          vim.lsp.inlay_hint.enable(true, { bufnr = buf })
        end
        if client.server_capabilities.codeLensProvider then
          vim.lsp.codelens.refresh({ bufnr = buf })
          vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "TextChanged" }, {
            buffer = buf,
            callback = function()
              vim.lsp.codelens.refresh({ bufnr = buf })
            end,
          })
          vim.keymap.set("n", "<leader>lr", vim.lsp.codelens.run, {
            buffer = buf,
            desc = "Run LSP code lens",
          })
        end
        -- Native LSP folding (Neovim 0.11+).
        if client.server_capabilities.foldingRangeProvider and vim.lsp.foldexpr then
          vim.api.nvim_set_option_value("foldmethod", "expr", { win = 0 })
          vim.api.nvim_set_option_value(
            "foldexpr",
            "v:lua.vim.lsp.foldexpr()",
            { win = 0 }
          )
        end
      end,
    })

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

    -- Configure servers using the new vim.lsp.config API
    if vim.env.ENV == "pio" then
      vim.lsp.config('ccls', {
        cmd = { 'ccls' },
        init_options = {
          compilationDatabaseDirectory = "build",
          index = { threads = 0 },
          clang = { excludeArgs = { "-frounding-math" } },
        },
        root_markers = { 'compile_commands.json', 'compile_flags.txt' },
        filetypes = { 'c', 'cpp' },
      })
      vim.lsp.enable('ccls')
    else
      vim.lsp.config('clangd', {
        cmd = { "clangd", "--header-insertion=never" },
        root_markers = { 'compile_commands.json', 'compile_flags.txt' },
        filetypes = { 'c', 'cpp' },
        capabilities = {
          textDocument = {
            inlayHint = {
              dynamicRegistration = false,
            },
          },
        },
      })
      vim.lsp.enable('clangd')
    end

    vim.lsp.config('rust_analyzer', {
      cmd = { 'rust-analyzer' },
      settings = {
        ["rust-analyzer"] = {
          diagnostics = { enable = false },
        },
      },
    })
    vim.lsp.enable('rust_analyzer')

    vim.lsp.config('qmlls', {
      cmd = { "qmlls6" },
    })
    vim.lsp.enable('qmlls')

    vim.lsp.config('pylsp', {
      cmd = { 'pylsp' },
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
    })
    vim.lsp.enable('pylsp')

    vim.lsp.config('lua_ls', {
      cmd = { 'lua-language-server' },
      settings = {
        Lua = {
          diagnostics = {
            globals = { 'vim' }
          }
        }
      }
    })
    vim.lsp.enable('lua_ls')

    -- Resolve `fol` to an absolute path so the LSP starts even when nvim was
    -- launched outside the project's direnv/nix shell (where `fol` is only on
    -- PATH inside the repo). PATH first (picks up the active dev build), then
    -- the dev-build fallbacks.
    local function fol_binary()
      local on_path = vim.fn.exepath('fol')
      if on_path ~= '' then
        return on_path
      end
      for _, candidate in ipairs({
        vim.fn.expand('~/data/code/bresilla/fol/target/debug/fol'),
        vim.fn.expand('~/data/code/bresilla/fol/target/release/fol'),
      }) do
        if vim.fn.executable(candidate) == 1 then
          return candidate
        end
      end
      return 'fol'
    end

    -- The bundled `std` package lives in the fol repo's `lang/library`; the LSP
    -- needs it as an explicit package-store root to resolve `use std: pkg = ...`
    -- (otherwise every std-using file fails with R1001 and semantic completion
    -- degrades). Include the flag only when the store directory exists.
    local fol_std_store = vim.fn.expand('~/data/code/bresilla/fol/lang/library')
    local fol_cmd = { fol_binary(), 'tool', 'lsp' }
    if vim.fn.isdirectory(fol_std_store) == 1 then
      fol_cmd = { fol_binary(), '--package-store-root', fol_std_store, 'tool', 'lsp' }
    end

    vim.lsp.config('fol', {
      cmd = fol_cmd,
      filetypes = { 'fol' },
      root_markers = { 'build.fol', 'fol.work.yaml', 'package.yaml', '.git' },
    })
    vim.lsp.enable('fol')

    -- Stig - Documentation checker for C/C++
    -- vim.lsp.enable('stig')
  end
}
