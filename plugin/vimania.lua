-- vimania.nvim - Advanced URI handling for modern Neovim
-- Plugin commands and key mappings

if vim.g.loaded_vimania then
  return
end
vim.g.loaded_vimania = 1

-- Check Neovim version compatibility
if vim.fn.has('nvim-0.7') == 0 then
  vim.notify('[vimania] Requires Neovim 0.7+', vim.log.levels.ERROR)
  return
end

-- Define plugin commands
vim.api.nvim_create_user_command('VimaniaHandleUri', function()
  require('vimania').handle_uri()
end, {
  desc = 'Handle URI at cursor position'
})

vim.api.nvim_create_user_command('VimaniaGetUrlTitle', function(opts)
  local url = opts.args
  if not url or url == '' then
    vim.notify('[vimania] Please provide a URL', vim.log.levels.WARN)
    return
  end
  
  require('vimania.http').set_vim_url_title(url)
end, {
  nargs = 1,
  desc = 'Get title for URL and set vim variable g:vimania_url_title'
})

vim.api.nvim_create_user_command('VimaniaPasteMdLink', function()
  require('vimania').paste_md_link()
end, {
  desc = 'Paste markdown link from clipboard URL'
})

vim.api.nvim_create_user_command('VimaniaFindLinkNext', function()
  require('vimania').find_next_link()
end, {
  desc = 'Find next link in buffer'
})

vim.api.nvim_create_user_command('VimaniaFindLinkPrev', function()
  require('vimania').find_prev_link()
end, {
  desc = 'Find previous link in buffer'
})

vim.api.nvim_create_user_command('VimaniaEdit', function(opts)
  local args = opts.args
  if not args or args == '' then
    vim.notify('[vimania] Please provide file path', vim.log.levels.WARN)
    return
  end
  
  require('vimania.navigator').edit_file_with_anchor(args)
end, {
  nargs = 1,
  desc = 'Edit file with optional anchor (path#anchor)'
})

vim.api.nvim_create_user_command('VimaniaTestHttp', function()
  require('vimania.http').test_http_client()
end, {
  desc = 'Test HTTP client functionality'
})

-- Compatibility commands (matching original plugin names)
vim.api.nvim_create_user_command('HandleMd', function()
  require('vimania').handle_uri()
end, {
  desc = 'Handle URI at cursor position (compatibility)'
})

vim.api.nvim_create_user_command('GetURLTitle', function(opts)
  local url = opts.args
  if not url or url == '' then
    vim.notify('[vimania] Please provide a URL', vim.log.levels.WARN)
    return
  end
  
  require('vimania.http').set_vim_url_title(url)
end, {
  nargs = 1,
  desc = 'Get URL title (compatibility)'
})

-- Create default key mappings if not already mapped
local function setup_default_mappings()
  -- Main URI handling mapping (go)
  if vim.fn.hasmapto('<Plug>(VimaniaHandleUri)', 'n') == 0 then
    vim.keymap.set('n', 'go', '<Plug>(VimaniaHandleUri)', {
      silent = true,
      desc = 'Handle URI at cursor'
    })
  end
  
  -- Paste markdown link mapping (<leader>vl)
  if vim.fn.hasmapto('<Plug>(VimaniaPasteMdLink)', 'n') == 0 then
    vim.keymap.set('n', '<leader>vl', '<Plug>(VimaniaPasteMdLink)', {
      silent = true,
      desc = 'Paste markdown link'
    })
  end
end

-- Define plug mappings
vim.keymap.set('n', '<Plug>(VimaniaHandleUri)', function()
  require('vimania').handle_uri()
end, { silent = true })

vim.keymap.set('n', '<Plug>(VimaniaPasteMdLink)', function()
  require('vimania').paste_md_link()
end, { silent = true })

vim.keymap.set('n', '<Plug>(VimaniaFindLinkNext)', function()
  require('vimania').find_next_link()
end, { silent = true })

vim.keymap.set('n', '<Plug>(VimaniaFindLinkPrev)', function()
  require('vimania').find_prev_link()
end, { silent = true })

-- Auto-setup with default configuration if no setup() was called
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- Small delay to allow user's init.lua to run first
    vim.defer_fn(function()
      if not require('vimania').is_initialized() then
        -- Auto-initialize with defaults
        require('vimania').setup()
        
        -- Set up default key mappings
        setup_default_mappings()
      end
    end, 100)
  end,
  once = true
})

-- Set up mappings immediately if vimania is already initialized  
if require('vimania').is_initialized() then
  setup_default_mappings()
end