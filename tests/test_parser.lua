-- Tests for vimania parser functionality using plenary.test_harness

local parser = require('vimania.parser')

-- Mock vim API for testing
local function mock_vim_api(cursor_pos, lines)
  _G.vim = _G.vim or {}
  vim.api = vim.api or {}
  
  vim.api.nvim_win_get_cursor = function()
    return { cursor_pos.row + 1, cursor_pos.col } -- Convert to 1-indexed for vim API
  end
  
  vim.api.nvim_buf_get_lines = function()
    return lines
  end
  
  vim.trim = vim.trim or function(s)
    return s:match('^%s*(.-)%s*$')
  end
  
  vim.pesc = vim.pesc or function(s)
    return (s:gsub('[%(%)%.%+%-%*%?%[%]%^%$%%]', '%%%1'))
  end
end

describe('parser', function()
  before_each(function()
    parser.setup({})
  end)
  
  describe('check_url_at_cursor', function()
    it('should find URL at cursor position', function()
      local line = 'Visit https://example.com for more info'
      local url = parser.check_url_at_cursor(line, 10) -- cursor on 'example.com'
      assert.are.equal('https://example.com', url)
    end)
    
    it('should return nil when cursor is not on URL', function()
      local line = 'Visit https://example.com for more info'
      local url = parser.check_url_at_cursor(line, 0) -- cursor at start
      assert.is_nil(url)
    end)
    
    it('should ignore URLs inside markdown links', function()
      local line = '[Link](https://example.com)'
      local url = parser.check_url_at_cursor(line, 10)
      assert.is_nil(url) -- Should be nil because it's part of markdown link
    end)
  end)
  
  describe('check_reference_definition', function()
    it('should parse reference definitions', function()
      local line = '[ref]: https://example.com'
      local link = parser.check_reference_definition(line)
      assert.are.equal('https://example.com', link)
    end)
    
    it('should handle whitespace in reference definitions', function()
      local line = '  [my-ref]:   https://example.com  '
      local link = parser.check_reference_definition(line)
      assert.are.equal('https://example.com', link)
    end)
    
    it('should return nil for non-reference lines', function()
      local line = 'This is not a reference definition'
      local link = parser.check_reference_definition(line)
      assert.is_nil(link)
    end)
  end)
  
  describe('find_reference_definition', function()
    it('should find reference definition in lines', function()
      local lines = {
        'Some text',
        '[ref]: https://example.com',
        'More text'
      }
      local link = parser.find_reference_definition('ref', lines)
      assert.are.equal('https://example.com', link)
    end)
    
    it('should return nil when reference not found', function()
      local lines = {
        'Some text',
        '[other]: https://example.com',
        'More text'
      }
      local link = parser.find_reference_definition('ref', lines)
      assert.is_nil(link)
    end)
  end)
  
  describe('parse_line_at_cursor', function()
    it('should parse direct markdown link', function()
      mock_vim_api({ row = 0, col = 5 }, { '[Link](test.md)' })
      local result = parser.parse_line_at_cursor()
      assert.are.equal('test.md', result)
    end)
    
    it('should parse URL', function()
      mock_vim_api({ row = 0, col = 10 }, { 'Visit https://example.com' })
      local result = parser.parse_line_at_cursor()
      assert.are.equal('https://example.com', result)
    end)
    
    it('should return nil when no link found', function()
      mock_vim_api({ row = 0, col = 5 }, { 'Just plain text' })
      local result = parser.parse_line_at_cursor()
      assert.is_nil(result)
    end)
  end)
  
  describe('select_from_start_of_link', function()
    it('should find link text from cursor position', function()
      local line = 'Some [link text](url) here'
      local link_text, rel_col = parser.select_from_start_of_link(line, 10)
      assert.are.equal('[link text](url)', link_text)
      assert.are.equal(5, rel_col) -- relative position within link
    end)
    
    it('should handle cursor at start of link', function()
      local line = '[link](url)'
      local link_text, rel_col = parser.select_from_start_of_link(line, 0)
      assert.are.equal('[link](url)', link_text)
      assert.are.equal(1, rel_col)
    end)
    
    it('should return nil when no link found', function()
      local line = 'No links here'
      local link_text, rel_col = parser.select_from_start_of_link(line, 5)
      assert.is_nil(link_text)
    end)
  end)
end)