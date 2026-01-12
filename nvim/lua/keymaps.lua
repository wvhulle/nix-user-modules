local map = vim.keymap.set

-- Buffer navigation (like helix S-l/S-h)
map('n', '<S-l>', ':bnext<CR>', { silent = true, desc = 'Next buffer' })
map('n', '<S-h>', ':bprev<CR>', { silent = true, desc = 'Previous buffer' })

-- LSP mappings
map('n', 'gd', vim.lsp.buf.definition, { desc = 'Go to definition' })
map('n', 'gD', vim.lsp.buf.declaration, { desc = 'Go to declaration' })
map('n', 'gi', vim.lsp.buf.implementation, { desc = 'Go to implementation' })
map('n', 'gr', vim.lsp.buf.references, { desc = 'References' })
map('n', 'K', vim.lsp.buf.hover, { desc = 'Hover documentation' })
map('n', '<leader>ca', vim.lsp.buf.code_action, { desc = 'Code action' })
map('n', '<leader>rn', vim.lsp.buf.rename, { desc = 'Rename symbol' })
map('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, { desc = 'Format buffer' })
map('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic' })

-- Diagnostics navigation
map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Previous diagnostic' })
map('n', ']d', vim.diagnostic.goto_next, { desc = 'Next diagnostic' })

-- Telescope mappings
map('n', '<leader>ff', '<cmd>Telescope find_files<CR>', { desc = 'Find files' })
map('n', '<leader>fg', '<cmd>Telescope live_grep<CR>', { desc = 'Live grep' })
map('n', '<leader>fb', '<cmd>Telescope buffers<CR>', { desc = 'Buffers' })
map('n', '<leader>fh', '<cmd>Telescope help_tags<CR>', { desc = 'Help tags' })
map('n', '<leader>fs', '<cmd>Telescope lsp_document_symbols<CR>', { desc = 'Document symbols' })
map('n', '<leader>fw', '<cmd>Telescope lsp_workspace_symbols<CR>', { desc = 'Workspace symbols' })
map('n', '<leader>fd', '<cmd>Telescope diagnostics<CR>', { desc = 'Diagnostics' })

-- Window navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Move to below window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Move to above window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })

-- Better escape
map('i', 'jk', '<Esc>', { desc = 'Exit insert mode' })
map('i', 'kj', '<Esc>', { desc = 'Exit insert mode' })

-- Clear search highlight
map('n', '<Esc>', ':noh<CR>', { silent = true, desc = 'Clear search highlight' })
