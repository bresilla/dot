-- Stig LSP - Documentation checker for C/C++
-- Provides diagnostics for missing/incomplete documentation
return {
  cmd = { 'stig', 'check' },
  filetypes = { 'c', 'cpp' },
  root_markers = { 'stig.toml', '.git' },
}
