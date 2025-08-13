-- Tests specifically for link selection and markdown parsing functions
-- These test the internal functions that support the main parsing logic

local parser = require('vimania.parser')

describe('link selection functions', function()
  before_each(function()
    parser.setup({})
  end)
  
  describe('select_from_start_of_link', function()
    describe('markdown link detection', function()
      it('should find markdown link when cursor is on link text', function()
        local line = '[GitHub - sysid/vimania-lua](https://github.com/sysid/vimania-lua)'
        
        -- Test various positions in the link text
        local positions = {0, 5, 10, 15, 20, 25} -- Different positions in "GitHub - sysid/vimania-lua"
        
        for _, pos in ipairs(positions) do
          local link_text, rel_col = parser.select_from_start_of_link(line, pos)
          assert.are.equal(line, link_text, string.format('Failed at position %d', pos))
          assert.is_number(rel_col)
          assert.is_true(rel_col > 0, string.format('Relative column should be positive at position %d', pos))
        end
      end)
      
      it('should find markdown link when cursor is on URL part', function()
        local line = '[GitHub](https://github.com/user/repo)'
        
        -- Test positions in the URL part
        local positions = {15, 20, 25, 30} -- Different positions in the URL
        
        for _, pos in ipairs(positions) do
          if pos < #line then
            local link_text, rel_col = parser.select_from_start_of_link(line, pos)
            assert.are.equal(line, link_text, string.format('Failed at position %d', pos))
            assert.is_number(rel_col)
          end
        end
      end)
      
      it('should find markdown link when cursor is on brackets or parentheses', function()
        local line = '[Link](url.com)'
        
        local test_cases = {
          {pos = 0, char = '['},
          {pos = 5, char = ']'},  
          {pos = 6, char = '('},
          {pos = 13, char = ')'}
        }
        
        for _, test in ipairs(test_cases) do
          local link_text, rel_col = parser.select_from_start_of_link(line, test.pos)
          assert.are.equal(line, link_text, string.format('Failed at position %d (char: %s)', test.pos, test.char))
          assert.is_number(rel_col)
        end
      end)
    end)
    
    describe('multiple links on same line', function()
      it('should find correct link when cursor is on first link', function()
        local line = '[First](url1.com) and [Second](url2.com)'
        
        -- Cursor positions within first link
        local positions = {0, 2, 5} -- Within "First"
        
        for _, pos in ipairs(positions) do
          local link_text, rel_col = parser.select_from_start_of_link(line, pos)
          assert.is_truthy(link_text:match('%[First%]'))
        end
      end)
      
      it('should find correct link when cursor is on second link', function() 
        local line = '[First](url1.com) and [Second](url2.com)'
        
        -- Cursor positions within second link
        local positions = {23, 25, 28} -- Within "Second"
        
        for _, pos in ipairs(positions) do
          local link_text, rel_col = parser.select_from_start_of_link(line, pos)
          assert.is_truthy(link_text:match('%[Second%]'))
        end
      end)
      
      it('should return nil when cursor is between links', function()
        local line = '[First](url1.com) and [Second](url2.com)'
        
        -- Cursor on " and " between links
        local link_text, rel_col = parser.select_from_start_of_link(line, 19)
        assert.is_nil(link_text)
      end)
    end)
    
    describe('edge cases', function()
      it('should handle empty line', function()
        local line = ''
        local link_text, rel_col = parser.select_from_start_of_link(line, 0)
        assert.is_nil(link_text)
      end)
      
      it('should handle line with no links', function()
        local line = 'Just plain text without any links'
        local link_text, rel_col = parser.select_from_start_of_link(line, 10)
        assert.is_nil(link_text)
      end)
      
      it('should handle malformed markdown links', function()
        local line = '[Incomplete link without closing'
        local link_text, rel_col = parser.select_from_start_of_link(line, 5)
        -- Should not crash, but may return nil
        assert.is_truthy(link_text == nil or type(link_text) == 'string')
      end)
      
      it('should handle nested brackets', function()
        local line = '[Text with [nested] brackets](https://example.com)'
        local link_text, rel_col = parser.select_from_start_of_link(line, 15)
        assert.are.equal(line, link_text)
      end)
    end)
  end)
  
  describe('parse_markdown_link_at_cursor', function()
    it('should extract URL from direct markdown links', function()
      local line = '[GitHub](https://github.com)'
      local lines = { line }
      
      local test_positions = {0, 3, 7, 10, 20}
      
      for _, pos in ipairs(test_positions) do
        if pos < #line then
          local result = parser.parse_markdown_link_at_cursor(line, pos, lines)
          assert.are.equal('https://github.com', result, string.format('Failed at position %d', pos))
        end
      end
    end)
    
    it('should handle URLs with paths and parameters', function()
      local line = '[Complex](https://api.example.com/v1/users?id=123&format=json)'
      local lines = { line }
      
      local result = parser.parse_markdown_link_at_cursor(line, 5, lines)
      assert.are.equal('https://api.example.com/v1/users?id=123&format=json', result)
    end)
    
    it('should handle reference links', function()
      local lines = {
        '[Reference link][ref1] and some text',
        '',
        '[ref1]: https://reference.example.com'
      }
      
      local result = parser.parse_markdown_link_at_cursor(lines[1], 5, lines)
      assert.are.equal('https://reference.example.com', result)
    end)
    
    it('should handle implicit reference links', function()
      local lines = {
        'Check [GitHub][] for info',
        '',
        '[GitHub]: https://github.com'
      }
      
      local result = parser.parse_markdown_link_at_cursor(lines[1], 8, lines)
      assert.are.equal('https://github.com', result)
    end)
    
    it('should return nil for invalid or missing references', function()
      local lines = {
        '[Missing reference][nonexistent]',
        '',
        '[other]: https://example.com'
      }
      
      local result = parser.parse_markdown_link_at_cursor(lines[1], 5, lines)
      assert.is_nil(result)
    end)
  end)
  
  describe('is_part_of_markdown_link', function()
    it('should detect URLs inside markdown links', function()
      local line = '[Link](https://example.com)'
      
      -- Position where "https://example.com" starts
      local url_start = line:find('https://')
      local is_part = parser.is_part_of_markdown_link(line, url_start)
      assert.is_true(is_part)
    end)
    
    it('should not detect standalone URLs as part of markdown links', function()
      local line = 'Visit https://example.com for info'
      
      local url_start = line:find('https://')
      local is_part = parser.is_part_of_markdown_link(line, url_start)
      assert.is_false(is_part)
    end)
    
    it('should handle multiple URLs correctly', function()
      local line = '[Link](https://first.com) and https://second.com'
      
      -- First URL (inside markdown)
      local first_url_start = line:find('https://first')
      local is_part1 = parser.is_part_of_markdown_link(line, first_url_start)
      assert.is_true(is_part1)
      
      -- Second URL (standalone)
      local second_url_start = line:find('https://second')
      local is_part2 = parser.is_part_of_markdown_link(line, second_url_start)
      assert.is_false(is_part2)
    end)
  end)
  
  describe('check_url_at_cursor for standalone URLs', function()
    it('should find standalone URLs', function()
      local line = 'Visit https://example.com for more info'
      
      -- Test different positions within the URL
      local test_positions = {8, 12, 18, 22}
      
      for _, pos in ipairs(test_positions) do
        local result = parser.check_url_at_cursor(line, pos)
        assert.are.equal('https://example.com', result, string.format('Failed at position %d', pos))
      end
    end)
    
    it('should ignore URLs that are part of markdown links', function()
      local line = '[Link](https://example.com)'
      
      -- Position within the URL part of the markdown link
      local url_pos = 15
      local result = parser.check_url_at_cursor(line, url_pos)
      assert.is_nil(result) -- Should be nil because it's part of markdown link
    end)
    
    it('should handle multiple URLs on same line', function()
      local line = 'Visit https://first.com and https://second.com'
      
      -- Test first URL
      local result1 = parser.check_url_at_cursor(line, 10)
      assert.are.equal('https://first.com', result1)
      
      -- Test second URL  
      local result2 = parser.check_url_at_cursor(line, 35)
      assert.are.equal('https://second.com', result2)
    end)
  end)
end)