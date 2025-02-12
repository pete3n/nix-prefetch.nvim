local M = {}

M.cfg = {
	ts_query_str = [[
  (apply_expression
    (select_expression
      (attrpath (identifier) @fetchName
        (#eq? @fetchName "fetchFromGitHub"))
    )
    (attrset_expression) @fetchBlock
  )
]],
}

M.ts_query = function()
	local query = vim.treesitter.query.parse("nix", M.cfg.ts_query_str)
	if not query then
		print("Failed to parse fetchFromGitHub")
		return nil
	end
	return query
end

M.get_cur_blk_coords = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cur_row = cursor[1] - 1 -- convert to 0-indexed
	local cur_col = cursor[2]

	local query = M.ts_query()
	if not query then
		return nil
	end

	local parser = vim.treesitter.get_parser(bufnr, "nix")
	if not parser then
		print("No parser available for nix!")
		return nil
	end
	local tree = parser:parse()[1]
	if not tree then
		print("No syntax tree found!")
		return nil
	end
	local root = tree:root()

	for id, node, _ in query:iter_captures(root, bufnr, 0, -1) do
		local capture_name = query.captures[id]
		if capture_name == "fetchBlock" then
			local s_row, s_col, e_row, e_col = node:range()
			if
				(cur_row > s_row or (cur_row == s_row and cur_col >= s_col))
				and (cur_row < e_row or (cur_row == e_row and cur_col <= e_col))
			then
				return node, s_row, s_col, e_row, e_col
			end
		end
	end
	return nil
end

M.parse_fetch_block = function(fetch_block_node)
  local buf = vim.api.nvim_get_current_buf()
  local block_text = vim.treesitter.get_node_text(fetch_block_node, buf)
  print("DEBUG: fetch_block node text:\n" .. block_text)

  local query_str = [[
    (binding
      (attrpath (identifier) @key)
      (string_expression) @value
    )
    (#match? @key "^(owner|repo|rev|hash)$")
  ]]
  local query = vim.treesitter.query.parse("nix", query_str)
  print("DEBUG: Running query:")
  print(query_str)

  local result = {}
  local match_count = 0

  -- Iterate over all matches in the fetch block node.
  for _, captures, _ in query:iter_matches(fetch_block_node, buf, 0, -1) do
    match_count = match_count + 1

    local key_node, value_node
    -- Iterate over the capture indices.
    for i, node in ipairs(captures) do
      local capture_name = query.captures[i]
      if capture_name == "key" then
        key_node = node
      elseif capture_name == "value" then
        value_node = node
      end
    end

    if key_node and value_node then
      local key_text = vim.trim(vim.treesitter.get_node_text(key_node, buf))
      local value_text = vim.trim(vim.treesitter.get_node_text(value_node, buf))
			value_text = value_text:gsub('^"(.*)"$', "%1")

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

M.get_attrs = function()
  -- Use select(1, ...) to get just the node (not all return values).
  local node = select(1, M.get_cur_blk_coords())
  if node then
    M.parse_fetch_block(node)
  else
    print("No fetch block node found.")
  end
end

return M
