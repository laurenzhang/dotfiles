-- loaded before lazy.nvim startup

-- use telescope instead of snacks.picker
vim.g.lazyvim_picker = "telescope"

vim.o.relativenumber = false

vim.o.clipboard = "unnamed"

-- enable project-specific .nvimrc
vim.o.exrc = true

-- do not keep backups or swapfiles
-- vim.o.nobackup = true
-- vim.o.nowritebackup = true
-- vim.o.noswapfile = true

-- ignore case when searching
vim.o.ignorecase = true
-- do incremental searching i.e. highlight as pattern typed
vim.o.incsearch = true

-- replace tab with spaces, except for makefiles
vim.o.expandtab = true
vim.o.autoindent = true
-- vim.o.nosmartindent = true
vim.o.softtabstop = 2
