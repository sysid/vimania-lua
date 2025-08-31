# vimania-lua

**Advanced URI Handling for Modern Neovim**

A pure Lua re-implementation of the [vimania-uri-rs](https://github.com/sysid/vimania-uri-rs)
plugin, providing lightning-fast URI navigation with zero external dependencies except
plenary.nvim.

- **Universal URI Support**: Handle web URLs, local files, internal links, and more
- **Smart Markdown Integration**: Auto-fetch page titles for reference-style links
- **Precise Navigation**: Jump to specific headings, line numbers, or anchors
- **Security First**: Built-in SSRF protection and comprehensive security auditing
- **Extensive Format Support**: Open HTML, DOCX, PPTX, images, audio, and more

## Why?

While Vim's native `gx` command and existing plugins provide basic URI handling, they often fall short in terms of:
- **Performance**: Slow startup times and laggy URL processing
- **Features**: Limited format support and navigation capabilities  
- **Security**: No protection against malicious URLs

vimania-lua addresses all these limitations with a modern, high-performance solution.

## Installation

### Using lazy.nvim
```lua
{
  'sysid/vimania-lua',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('vimania').setup({
      -- Optional configuration (see Configuration section)
    })
  end
}
```

Then in your `init.lua`:
```lua
require('vimania').setup()
```

## Quick Start

**It's simple**: Position your cursor on any URI and press `go`.

```
go
```

That's it! The plugin intelligently determines how to handle the URI based on its type and context.

### Link Detection

In normal mode in a Markdown document, type `go` while curser is on markdown-link.

The following links will be handled (the possible cursor positions are indicated by `^`):

    Local text links: [link](foo.md) will be opened inside vim. 
                      ^^^^^^^^^^^^^^
    If target contains line number as in [link](foo.md:30), the line will be jumped to. 
    Also anchors are supported, for example [link](foo.md#anchor)

    This [link](https://example.com) will be opened inside the browser.
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^

    This $HOME/dir will be opened inside OS file browser
         ^^^^^^^^^

    This $HOME/dir/present.pptx will open in Powerpoint
         ^^^^^^^^^^^^^^^^^^^^^^

    [link](example.pdf) will be opened in pdf reader
    ^^^^^^^^^^^^^^^^^^^

    Document internal linking works, too: to link to the heading Usage, use
    this [link](#usage).
         ^^^^^^^^^^^^^^

    Reference style [links][ref-style-link] will open http://example.com in browser
                    ^^^^^^^^^^^^^^^^^^^^^^^
    [ref-style-link]: http://example.com

## Supported Link Types

### Local Text Links
`[foo](second.md)` will be opened inside Neovim.
If the target contains line number as in `[foo](second.md:30)`, the line will be jumped to.
Also anchors are supported, for example `[foo](second.md#custom-id)`.

### URL Links
`[google](https://google.com)` will be opened with the OS browser.

### Non-Text Files
If the file extension is not in the `extensions` configuration, non-text files will be opened via the operating system.
This behavior is handy when linking to binary documents, for example PDFs.

### Internal Links
`[Link Text](#Target)`, will link to the heading `# Target`.
Following the link will jump to the heading inside Neovim.
Currently both GitHub style anchors (all words lowercased and hyphenated) and custom IDs are supported.

### Reference Style Links
For links of the form `[foo][label]`, vimania will lookup the corresponding label and open the target referenced there.

### Implicit Name Links
For links of the form `[foo][]` will use `foo` as the label and then follow the logic of reference style links.

### Custom IDs via Attribute Lists
The ID a link target can be defined via attribute lists of the form `{: #someid ...}`.
This way fixed name references can be defined to prevent links from going stale after headings have been changed.

### Pelican Link Format
Vimania handles `|filename|` and `{filename}` links as expected, for example `[link](|filename|./second.md)` and `[link]({filename}../posts/second.md)`.

## ⚙️ Configuration

### Default Configuration
```lua
require('vimania').setup({
  -- File extensions to open in Neovim (others use OS default)
  extensions = { '.md', '.txt', '.rst', '.py', '.conf', '.sh', '.json', '.yaml', '.yml' },
  
  -- Key mapping for URI navigation (default: 'go')  
  key_mapping = 'go',
  
  -- Timeout for HTTP requests (milliseconds)
  timeout = 3000,
  
  -- Log level (DEBUG, INFO, WARNING, ERROR)
  log_level = 'INFO',
  
  -- Custom browser command (optional)
  browser_cmd = nil,
  
  -- Security settings
  security = {
    -- Block access to local/internal networks (SSRF protection)
    block_local_networks = true,
    -- Allowed URL schemes
    allowed_schemes = { 'http', 'https' }
  }
})
```

### Custom Key Mappings
If you prefer different key mappings:

```lua
require('vimania').setup({
  key_mapping = '<leader>go' -- Use leader+go instead of just go
})
```

Or disable automatic mappings and create your own:
```lua
require('vimania').setup({
  key_mapping = nil -- Disable automatic mapping
})

-- Create custom mappings
vim.keymap.set('n', '<leader>u', function() require('vimania').handle_uri() end, { desc = 'Handle URI' })
vim.keymap.set('n', '<leader>vl', function() require('vimania').paste_md_link() end, { desc = 'Paste MD link' })
```

## Commands

- `:VimaniaHandleUri` - Handle URI at cursor position
- `:VimaniaGetUrlTitle <url>` - Get title for URL and set vim variable
- `:VimaniaPasteMdLink` - Paste markdown link from clipboard URL
- `:VimaniaFindLinkNext` - Find next link in buffer
- `:VimaniaFindLinkPrev` - Find previous link in buffer
- `:VimaniaEdit <path#anchor>` - Edit file with optional anchor
- `:VimaniaTestHttp` - Test HTTP client functionality

### Compatibility Commands
For compatibility with the original plugin:
- `:HandleMd` - Same as `:VimaniaHandleUri`
- `:GetURLTitle <url>` - Same as `:VimaniaGetUrlTitle`

## Default Key Mappings

- `go` - Handle URI at cursor (`<Plug>(VimaniaHandleUri)`)
- `<leader>vl` - Paste markdown link from clipboard (`<Plug>(VimaniaPasteMdLink)`)

Additional plug mappings available:
- `<Plug>(VimaniaFindLinkNext)` - Find next link
- `<Plug>(VimaniaFindLinkPrev)` - Find previous link

## Security Features

### SSRF Protection
The plugin includes built-in protection against Server-Side Request Forgery (SSRF) attacks:

- Blocks access to local networks (127.0.0.1, localhost, 192.168.x.x, etc.)
- Only allows HTTP and HTTPS schemes by default
- Validates URLs before making requests

You can configure security settings:
```lua
require('vimania').setup({
  security = {
    block_local_networks = false, -- Disable local network blocking
    allowed_schemes = { 'http', 'https', 'ftp' } -- Allow additional schemes
  }
})
```

## Testing

### Running Tests

**Run all tests:**
```bash
# Headless mode (for CI/automation)
nvim --headless -c "lua require('tests.run_tests')" -c "qa"

# Interactive mode (for development)
nvim -c "lua require('plenary.test_harness').test_directory('tests')"
```

**Run specific test files:**
```bash
# Test utility functions
nvim --headless -c "PlenaryBustedFile tests/test_utils.lua" -c "qa"

# Test parsing logic
nvim --headless -c "PlenaryBustedFile tests/test_parser.lua" -c "qa"
```

### Manual Testing

**Test with sample data:**
```bash
# Open the test document with various link types
nvim tests/test_data/test.md

# Position cursor on different links and press 'go' to test functionality
```

**Test HTTP functionality:**
```vim
" Test URL title fetching
:VimaniaGetUrlTitle https://www.example.com

" Test HTTP client
:VimaniaTestHttp

" Test clipboard markdown link pasting (copy a URL first)
:VimaniaPasteMdLink
```

## Troubleshooting

Enable debug logging to troubleshoot issues:
```lua
require('vimania').setup({
  log_level = 'DEBUG'
})
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality  
4. Run the test suite
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Credits

- Original inspiration from [vimania-uri-rs](https://github.com/sysid/vimania-uri-rs)
- Built with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
