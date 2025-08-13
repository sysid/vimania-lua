-- Utility functions for vimania.nvim

local M = {}

-- URL pattern matching - Lua version of URL_PATTERN from pattern.py
local URL_PATTERN = 'https?://[%w%.%-_~:/?#%[%]@!%$&\'%(%)%*%+,;=%%]+'

-- Check if a string is a valid URL
function M.is_url(str)
  if not str or type(str) ~= 'string' then
    return false
  end
  
  str = vim.trim(str)
  return str:match('^' .. URL_PATTERN .. '$') ~= nil
end

-- Parse URL to extract components
function M.parse_url(url)
  if not M.is_url(url) then
    return nil
  end
  
  -- Simple URL parsing - extract scheme, host, path
  local scheme, host, path = url:match('(https?)://([^/]+)(.*)$')
  if not scheme or not host then
    return nil
  end
  
  return {
    scheme = scheme,
    host = host,
    path = path or '',
    full_url = url
  }
end

-- Check if a host is a local/internal network (SSRF protection)
function M.is_local_network(host)
  if not host then
    return false
  end
  
  -- Convert to lowercase for comparison
  host = host:lower()
  
  -- Check for localhost variations
  if host == 'localhost' or host == '127.0.0.1' or host == '::1' then
    return true
  end
  
  -- Check for private IP ranges
  local private_ranges = {
    '^192%.168%.',     -- 192.168.x.x
    '^10%.',           -- 10.x.x.x
    '^172%.1[6-9]%.',  -- 172.16.x.x - 172.19.x.x
    '^172%.2[0-9]%.',  -- 172.20.x.x - 172.29.x.x  
    '^172%.3[0-1]%.',  -- 172.30.x.x - 172.31.x.x
  }
  
  for _, pattern in ipairs(private_ranges) do
    if host:match(pattern) then
      return true
    end
  end
  
  return false
end

-- Parse file path with optional line number and anchor
-- Equivalent to parse_uri from mdnav.py
function M.parse_file_path(uri)
  if not uri or uri == '' then
    return { path = '' }
  end
  
  -- Check if it's a URL scheme
  if M.is_url(uri) then
    return { 
      path = uri,
      scheme = uri:match('^([^:]+):')
    }
  end
  
  local path = uri
  local line = nil
  local anchor = nil
  
  -- Check for anchor (#heading)
  local anchor_pos = path:find('#')
  if anchor_pos then
    anchor = path:sub(anchor_pos + 1)
    path = path:sub(1, anchor_pos - 1)
  end
  
  -- Check for line number (:30)
  local colon_pos = path:find(':(%d+)$')
  if colon_pos then
    line = tonumber(path:match(':(%d+)$'))
    path = path:gsub(':(%d+)$', '')
  end
  
  -- Expand variables and user home
  path = vim.fn.expand(path)
  
  return {
    path = path,
    line = line,
    anchor = anchor,
    fullpath = vim.fn.fnamemodify(path, ':p')
  }
end

-- Check if file has a supported extension
function M.has_supported_extension(path, extensions)
  if not extensions or #extensions == 0 then
    return true
  end
  
  local ext = vim.fn.fnamemodify(path, ':e')
  if ext and ext ~= '' then
    ext = '.' .. ext
    for _, allowed_ext in ipairs(extensions) do
      if allowed_ext == ext then
        return true
      end
    end
  end
  
  return false
end

-- Escape file path for safe use in vim commands
function M.escape_path(path)
  if not path then
    return ''
  end
  
  -- Escape spaces and special characters
  return path:gsub(' ', '\\ ')
end

-- Get current cursor position (0-indexed for compatibility)
function M.get_cursor_pos()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return {
    row = cursor[1] - 1,  -- Convert to 0-indexed
    col = cursor[2]
  }
end

-- Get current buffer lines
function M.get_buffer_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Get current line
function M.get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1] or ''
end

-- Create title to anchor conversion (GitHub style)
-- Equivalent to title_to_anchor from mdnav.py
function M.title_to_anchor(title)
  if not title then
    return ''
  end
  
  -- Remove punctuation (keep hyphens)
  local punctuation = '["#$%%&\'%(%)%*%+,./:;<=>?@%[\\%]^_`{|}~!]'
  title = title:gsub(punctuation, '')
  
  -- Convert to lowercase and replace spaces with hyphens
  title = title:lower()
  title = title:gsub('%s+', '-')
  
  return title
end

-- Log function that respects log level
function M.log(level, message)
  local config = require('vimania.config')
  local current_level = config.get_log_level()
  
  local levels = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4
  }
  
  if levels[level] and levels[current_level] and levels[level] >= levels[current_level] then
    local vim_levels = {
      DEBUG = vim.log.levels.DEBUG,
      INFO = vim.log.levels.INFO,
      WARNING = vim.log.levels.WARN,
      ERROR = vim.log.levels.ERROR
    }
    
    -- Use vim.schedule to avoid fast event context errors
    vim.schedule(function()
      vim.notify('[vimania] ' .. message, vim_levels[level] or vim.log.levels.INFO)
    end)
  end
end

return M