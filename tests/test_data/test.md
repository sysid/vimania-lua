# Test Document

This is a test document for vimania.nvim functionality.

## Working Examples

Here are various types of links for testing:

### Direct Links
- [Local file](./other.md)
- [Local file with line](./other.md:30)
- [Local file with anchor](./other.md#heading)
- [Web URL](https://www.google.com)
- [Another URL](https://github.com/neovim/neovim)

### Reference Links
- [Reference link][ref1]
- [Another ref][ref2] 
- [Implicit ref][]

### Internal Links
- [Internal heading](#second-heading)
- [Custom anchor](#custom-id)

### File Paths
- /path/to/file.txt
- ~/documents/test.md
- ./relative/path.md

### URLs
- https://www.example.com
- http://httpbin.org/get

## Second Heading

This is the second heading for testing internal navigation.

## Custom ID Test {: #custom-id}

This heading has a custom ID for testing attribute list parsing.

## Reference Definitions

[ref1]: https://www.example.com
[ref2]: ./local-file.md
[Implicit ref]: https://implicit.example.com