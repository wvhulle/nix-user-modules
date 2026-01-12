-- Diagnostic and LSP UI configuration

vim.diagnostic.config({
  virtual_text = {
    prefix = '●',
    source = 'if_many',
  },
  float = {
    border = 'rounded',
    source = 'if_many',
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- LSP UI improvements
vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
  vim.lsp.handlers.hover,
  { border = 'rounded' }
)
vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
  vim.lsp.handlers.signature_help,
  { border = 'rounded' }
)
