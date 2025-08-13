-- Link parsing and pattern matching for vimania.nvim
-- Lua port of mdnav.py and pattern.py functionality

local M = {}
local utils = require('vimania.utils')

-- Patterns for different link types (converted from Python regex to Lua patterns)
local patterns = {
  -- Basic URL pattern
  url = 'https?://[%w%.%-_~:/?#%[%]@!%$&\'%(%)%*%+,;=%%]+',
  
  -- Markdown link pattern [text](url)
  md_link = '%[([^%]]*)%]%(([^%)]+)%)',
  
  -- Reference link pattern [text][ref] or [text][]
  ref_link = '%[([^%]]*)%]%[([^%]]*)%]',
  
  -- Reference definition pattern [ref]: url
  ref_def = '^%s*%[([^%]]*)%]:%s*(.+)$',
  
  -- Internal link pattern #heading
  internal_link = '#[%w%s%-_]+',
  
  -- Heading pattern for anchor matching
  heading = '^#+%s*(.+)$',
  
  -- Attribute list pattern {: #id}
  attr_list = '{:%s*#([%w%-_]+)%s*[^}]*}'
}

-- State
local state = {
  config = {}
}

-- Setup function
function M.setup(config)
  state.config = config or {}
end

-- Parse the current line to extract URI under cursor
-- Equivalent to parse_line from mdnav.py
function M.parse_line_at_cursor()
  local cursor_pos = utils.get_cursor_pos()
  local lines = utils.get_buffer_lines()
  
  if cursor_pos.row >= #lines then
    return nil
  end
  
  local line = lines[cursor_pos.row + 1] -- Convert back to 1-indexed for line access
  local column = cursor_pos.col
  
  utils.log('DEBUG', string.format('Parsing line: %s (row: %d, col: %d)', line, cursor_pos.row, column))
  
  -- Try different parsing methods in order of priority
  
  -- 1. Check for markdown link first (highest priority)
  local md_link = M.parse_markdown_link_at_cursor(line, column, lines)
  if md_link then
    utils.log('DEBUG', 'Found markdown link: ' .. md_link)
    return md_link
  end
  
  -- 2. Check for standalone URL under cursor (only if not in markdown link)
  local url = M.check_url_at_cursor(line, column)
  if url then
    utils.log('DEBUG', 'Found standalone URL: ' .. url)
    return url
  end
  
  -- 3. Check for reference definition
  local ref_link = M.check_reference_definition(line)
  if ref_link then
    utils.log('DEBUG', 'Found reference definition: ' .. ref_link)
    return ref_link
  end
  
  -- 4. Check for file path
  local file_path = M.check_file_path_at_cursor(line, column)
  if file_path then
    utils.log('DEBUG', 'Found file path: ' .. file_path)
    return file_path
  end
  
  utils.log('INFO', 'No link found at cursor position')
  return nil
end

-- Check if cursor is on a standalone URL (not in markdown links)
function M.check_url_at_cursor(line, column)
  -- Find all URLs in the line
  local start_pos = 1
  while true do
    local url_start, url_end = line:find(patterns.url, start_pos)
    if not url_start then
      break
    end
    
    -- Check if cursor is within this URL
    if url_start - 1 <= column and column < url_end then
      local url = line:sub(url_start, url_end)
      -- Only return standalone URLs (markdown links are handled separately)
      if not M.is_part_of_markdown_link(line, url_start) then
        return vim.trim(url)
      end
    end
    
    start_pos = url_end + 1
  end
  
  return nil
end

-- Check if a URL position is part of a markdown link
function M.is_part_of_markdown_link(line, url_start)
  -- Check if there's a ')' after the URL, indicating it's in a markdown link
  local after_url = line:sub(url_start)
  return after_url:match('^[^%)]*%)') ~= nil
end

-- Check for reference definition [ref]: url
function M.check_reference_definition(line)
  local ref, link = line:match(patterns.ref_def)
  if ref and link then
    return vim.trim(link)
  end
  return nil
end

-- Check for file path under cursor
function M.check_file_path_at_cursor(line, column)
  if column >= #line then
    return nil
  end
  
  -- Skip if cursor is on whitespace
  local char = line:sub(column + 1, column + 1)
  if char:match('%s') then
    return nil
  end
  
  -- Find word boundaries around cursor
  local start_pos = column + 1
  local end_pos = column + 1
  
  -- Find start of path
  while start_pos > 1 do
    local c = line:sub(start_pos - 1, start_pos - 1)
    if c:match('%s') then
      break
    end
    start_pos = start_pos - 1
  end
  
  -- Find end of path
  while end_pos <= #line do
    local c = line:sub(end_pos, end_pos)
    if c:match('%s') then
      break
    end
    end_pos = end_pos + 1
  end
  
  local potential_path = line:sub(start_pos, end_pos - 1)
  
  -- Validate it looks like a path (basic validation)
  if potential_path and #potential_path > 0 then
    -- Skip if it contains characters that suggest it's not a file path
    local invalid_chars = '[*?|"\'<>!]'
    if not potential_path:match(invalid_chars) then
      return potential_path
    end
  end
  
  return nil
end

-- Parse markdown link at cursor position
function M.parse_markdown_link_at_cursor(line, column, all_lines)
  local link_text, rel_column = M.select_from_start_of_link(line, column)
  
  if not link_text then
    return nil
  end
  
  -- Try to match different link patterns
  
  -- Direct link [text](url)
  local text, direct_link = link_text:match('^%[([^%]]*)%]%(([^%)]+)%)')
  if direct_link then
    return vim.trim(direct_link)
  end
  
  -- Reference link [text][ref] or [text][]
  local ref_text, ref_name = link_text:match('^%[([^%]]*)%]%[([^%]]*)%]')
  if ref_text then
    -- Use link text as reference if ref_name is empty
    if ref_name == '' then
      ref_name = ref_text
    end
    
    -- Look for reference definition in all lines
    return M.find_reference_definition(ref_name, all_lines)
  end
  
  return nil
end

-- Find the start of a link from cursor position
function M.select_from_start_of_link(line, cursor_pos)
  -- Convert to 1-indexed position
  local cursor_1_indexed = cursor_pos + 1
  
  -- First, try to find if we're anywhere within a markdown link pattern [text](url)
  -- Search for all markdown links in the line and see if cursor falls within any of them
  local start_search = 1
  while true do
    local bracket_start = line:find('%[', start_search)
    if not bracket_start then
      break
    end
    
    -- Find the matching closing bracket
    local bracket_end = line:find('%]', bracket_start + 1)
    if not bracket_end then
      start_search = bracket_start + 1
      goto continue
    end
    
    -- Check if there's a parenthetical part after the bracket
    local paren_start = line:find('%(', bracket_end + 1)
    if paren_start and paren_start == bracket_end + 1 then
      -- Find the matching closing parenthesis
      local paren_end = line:find('%)', paren_start + 1)
      if paren_end then
        -- Check if cursor is anywhere within this markdown link
        if bracket_start <= cursor_1_indexed and cursor_1_indexed <= paren_end then
          local link_text = line:sub(bracket_start)
          local rel_column = cursor_1_indexed - bracket_start + 1
          return link_text, rel_column
        end
      end
    end
    
    start_search = bracket_start + 1
    ::continue::
  end
  
  -- If no markdown link found, try the original approach for reference links
  local start_pos = cursor_1_indexed
  
  if start_pos <= #line and line:sub(start_pos, start_pos) == '[' then
    -- cursor is on '['
  else
    -- Find the last '[' before cursor
    local search_pos = start_pos - 1
    while search_pos > 0 do
      if line:sub(search_pos, search_pos) == '[' then
        start_pos = search_pos
        break
      end
      search_pos = search_pos - 1
    end
    
    if search_pos == 0 then
      return nil, cursor_pos
    end
  end
  
  -- Check for reference links (][)
  if start_pos > 1 and line:sub(start_pos - 1, start_pos - 1) == ']' then
    -- Look for an earlier '['
    local alt_start = start_pos - 2
    while alt_start > 0 do
      if line:sub(alt_start, alt_start) == '[' then
        start_pos = alt_start
        break
      end
      alt_start = alt_start - 1
    end
  end
  
  local link_text = line:sub(start_pos)
  local rel_column = cursor_pos - start_pos + 1
  
  return link_text, rel_column
end

-- Find reference definition in all buffer lines
function M.find_reference_definition(ref_name, lines)
  if not ref_name or ref_name == '' then
    return nil
  end
  
  -- Create pattern to match reference definition
  local pattern = '^%s*%[' .. vim.pesc(ref_name) .. '%]:%s*(.+)$'
  
  for _, line in ipairs(lines) do
    local link = line:match(pattern)
    if link then
      return vim.trim(link)
    end
  end
  
  return nil
end

-- Find next link in the buffer
function M.find_next_link()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Search from current position onwards
  for row = cursor_pos[1], #lines do
    local line = lines[row]
    local search_from = (row == cursor_pos[1]) and cursor_pos[2] + 1 or 1
    
    -- Look for markdown links
    local link_start = line:find('%[.-%]%b()', search_from)
    if not link_start then
      link_start = line:find('%[.-%]%b[]', search_from)
    end
    
    if link_start then
      vim.api.nvim_win_set_cursor(0, { row, link_start - 1 })
      return
    end
  end
  
  utils.log('INFO', 'No more links found')
end

-- Find previous link in the buffer
function M.find_prev_link()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Search backwards from current position
  for row = cursor_pos[1], 1, -1 do
    local line = lines[row]
    local search_to = (row == cursor_pos[1]) and cursor_pos[2] or #line
    
    -- Find all links in the line and take the last one before cursor
    local last_match = nil
    local start_pos = 1
    
    while start_pos <= search_to do
      local link_start = line:find('%[.-%]%b()', start_pos)
      if not link_start then
        link_start = line:find('%[.-%]%b[]', start_pos)
      end
      
      if link_start and link_start < search_to then
        last_match = link_start
        start_pos = link_start + 1
      else
        break
      end
    end
    
    if last_match then
      vim.api.nvim_win_set_cursor(0, { row, last_match - 1 })
      return
    end
  end
  
  utils.log('INFO', 'No previous links found')
end

return M