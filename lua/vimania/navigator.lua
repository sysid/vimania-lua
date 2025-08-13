-- URI navigation and file handling for vimania.nvim  
-- Lua port of mdnav.py action classes and navigation logic

local M = {}
local utils = require('vimania.utils')

-- State
local state = {
  config = {}
}

-- Setup function
function M.setup(config)
  state.config = config or {}
end

-- Action types for different URI handling
local Actions = {}

-- No-op action when no link is found
function Actions.no_op(target)
  vim.notify('[vimania] No link found at cursor', vim.log.levels.INFO)
end

-- Browser action for web URLs
function Actions.browser_open(target)
  utils.log('DEBUG', 'Opening URL in browser: ' .. target)
  vim.notify('[vimania] Opening browser tab', vim.log.levels.INFO)
  
  local config = require('vimania.config')
  local browser_cmd = config.get_browser_cmd()
  
  local cmd
  if browser_cmd then
    cmd = { browser_cmd, target }
  else
    -- Use OS default browser
    if vim.fn.has('mac') == 1 then
      cmd = { 'open', target }
    elseif vim.fn.has('unix') == 1 then
      cmd = { 'xdg-open', target }
    elseif vim.fn.has('win32') == 1 then
      cmd = { 'cmd', '/c', 'start', target }
    else
      vim.notify('[vimania] Unsupported platform for browser opening', vim.log.levels.ERROR)
      return
    end
  end
  
  -- Use vim.system for non-blocking execution
  vim.system(cmd, { detach = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify('[vimania] Failed to open browser: ' .. (result.stderr or ''), vim.log.levels.ERROR)
      end)
    end
  end)
end

-- OS action for files that should be opened by the operating system
function Actions.os_open(target)
  local parsed = utils.parse_file_path(target)
  
  if not vim.fn.filereadable(parsed.fullpath) then
    vim.notify('[vimania] File does not exist: ' .. parsed.fullpath, vim.log.levels.ERROR)
    return
  end
  
  utils.log('DEBUG', 'Opening file with OS: ' .. parsed.fullpath)
  
  local cmd
  if vim.fn.has('mac') == 1 then
    cmd = { 'open', parsed.fullpath }
  elseif vim.fn.has('unix') == 1 then
    cmd = { 'xdg-open', parsed.fullpath }
  elseif vim.fn.has('win32') == 1 then
    cmd = { 'cmd', '/c', 'start', parsed.fullpath }
  else
    vim.notify('[vimania] Unsupported platform for OS file opening', vim.log.levels.ERROR)
    return
  end
  
  vim.system(cmd, { detach = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        vim.notify('[vimania] Failed to open file with OS: ' .. (result.stderr or ''), vim.log.levels.ERROR)
      end)
    end
  end)
end

-- Vim action for files that should be opened in Neovim
function Actions.vim_open(target)
  local parsed = utils.parse_file_path(target)
  
  utils.log('DEBUG', 'Opening file in Neovim: ' .. parsed.fullpath)
  
  -- Create directory if it doesn't exist (for new files)
  if not vim.fn.filereadable(parsed.fullpath) then
    local dir = vim.fn.fnamemodify(parsed.fullpath, ':h')
    if not vim.fn.isdirectory(dir) then
      vim.fn.mkdir(dir, 'p')
    end
    utils.log('INFO', 'Creating new file: ' .. parsed.fullpath)
  end
  
  -- Open file in new tab
  local escaped_path = utils.escape_path(parsed.fullpath)
  vim.cmd('tabnew ' .. escaped_path)
  
  -- Jump to specific line if specified
  if parsed.line then
    local line_num = tonumber(parsed.line)
    if line_num and line_num > 0 then
      vim.api.nvim_win_set_cursor(0, { line_num, 0 })
    end
  end
  
  -- Jump to anchor if specified
  if parsed.anchor then
    Actions.jump_to_anchor(parsed.anchor)
  end
end

-- Jump to anchor/heading within current document
function Actions.jump_to_anchor(target)
  -- Remove leading # if present
  if target:sub(1, 1) == '#' then
    target = target:sub(2)
  end
  
  utils.log('DEBUG', 'Jumping to anchor: ' .. target)
  
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local target_line = M.find_anchor_line(target, lines)
  
  if target_line then
    vim.api.nvim_win_set_cursor(0, { target_line + 1, 0 }) -- Convert to 1-indexed
    utils.log('DEBUG', 'Jumped to line: ' .. (target_line + 1))
  else
    vim.notify('[vimania] Anchor not found: ' .. target, vim.log.levels.WARN)
  end
end

-- Find line number for anchor/heading
function M.find_anchor_line(target, lines)
  local normalized_target = utils.title_to_anchor(target)
  
  for i, line in ipairs(lines) do
    -- Check for markdown heading
    local heading = line:match('^#+%s*(.+)$')
    if heading then
      local heading_anchor = utils.title_to_anchor(heading)
      if heading_anchor == normalized_target then
        return i - 1 -- Return 0-indexed
      end
    end
    
    -- Check for custom ID in attribute lists {: #custom-id}
    local custom_id = line:match('{:%s*#([%w%-_]+)%s*[^}]*}')
    if custom_id and custom_id == target then
      return i - 1 -- Return 0-indexed
    end
  end
  
  return nil
end

-- Determine appropriate action for a given URI
function M.get_action_for_uri(target)
  if not target or target == '' then
    return Actions.no_op
  end
  
  target = vim.trim(target)
  
  -- Internal anchor link
  if target:sub(1, 1) == '#' then
    return function() Actions.jump_to_anchor(target) end
  end
  
  -- Web URL
  if utils.is_url(target) then
    return function() Actions.browser_open(target) end
  end
  
  -- Handle pelican-style links
  if target:sub(1, 11) == '|filename|' then
    target = target:sub(12) -- Remove |filename| prefix
  elseif target:sub(1, 10) == '{filename}' then
    target = target:sub(11) -- Remove {filename} prefix
  end
  
  -- Check if file should be opened in Neovim
  local config = require('vimania.config')
  if config.should_open_in_nvim(target) then
    return function() Actions.vim_open(target) end
  else
    return function() Actions.os_open(target) end
  end
end

-- Main URI handling function - equivalent to call_handle_md2
function M.handle_uri_at_cursor()
  local parser = require('vimania.parser')
  local target = parser.parse_line_at_cursor()
  
  if not target then
    Actions.no_op()
    return
  end
  
  utils.log('INFO', 'Handling URI: ' .. target)
  
  local action = M.get_action_for_uri(target)
  local ok, err = pcall(action)
  
  if not ok then
    vim.notify('[vimania] Error handling URI: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Edit function for backward compatibility (equivalent to edit_vimania)
function M.edit_file_with_anchor(args)
  if not args or args == '' then
    vim.notify('[vimania] No arguments provided to edit function', vim.log.levels.WARN)
    return
  end
  
  local path, anchor = args:match('^([^#]*)#?(.*)$')
  if not path then
    path = args
    anchor = ''
  end
  
  utils.log('DEBUG', string.format('Edit file: path=%s, anchor=%s', path, anchor))
  
  -- Open file in new tab
  local escaped_path = utils.escape_path(vim.fn.expand(path))
  vim.cmd('tabnew ' .. escaped_path)
  
  -- Jump to anchor if provided
  if anchor and anchor ~= '' then
    -- Use vim search to find the anchor
    vim.cmd('/' .. vim.fn.escape(anchor, '/\\'))
  end
end

return M