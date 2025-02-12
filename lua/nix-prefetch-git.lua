M.parse_fetch_block = function(fetch_block_node)
  local buf = vim.api.nvim_get_current_buf()
  local block_text = vim.treesitter.get_node_text(fetch_block_node, buf)
  print("DEBUG: fetch_block node text:\n" .. block_text)

  local query_str = [[
    (binding
      (attrpath (attr) @key)
      (string_expression (string_fragment) @value)
    )
    (#match? @key "^(owner|repo|rev|hash)$")
  ]]
  local query = vim.treesitter.query.parse("nix", query_str)
  print("DEBUG: Running query:")
  print(query_str)

  local result = {}
  local match_count = 0

  for _, captures, _ in query:iter_matches(fetch_block_node, buf, 0, -1) do
    match_count = match_count + 1
    local key_node = captures[query.captures.key]
    local value_node = captures[query.captures.value]
    if key_node and value_node then
      local key_text = vim.trim(vim.treesitter.get_node_text(key_node, buf))
      local value_text = vim.trim(vim.treesitter.get_node_text(value_node, buf))
      print(string.format("DEBUG: Match #%d", match_count))
      print("  Capture key: " .. key_text)
      print("  Capture value: " .. value_text)
      result[key_text] = value_text
    else
      print(string.format("DEBUG: Match #%d missing key or value", match_count))
    end
  end

  print("DEBUG: Final result:")
  print(vim.inspect(result))
  return result
end
