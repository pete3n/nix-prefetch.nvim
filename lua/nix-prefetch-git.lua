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
  local query_str = [[
    (binding
      (attrpath (identifier) @key)
      (string_expression (string_fragment) @value)
    )
    (#match? @key "^(owner|repo|rev|hash)$")
  ]]
  local query = vim.treesitter.query.parse("nix", query_str)
  local result = {}

  for _, captures, _ in query:iter_matches(fetch_block_node, buf, 0, -1) do
    local key = vim.treesitter.get_node_text(captures[query.captures.key], buf)
    local value = vim.treesitter.get_node_text(captures[query.captures.value], buf)
    result[key] = value
  end

  return result
end

M.get_attrs = function()
	local node, _, _, _, _ = M.get_cur_blk_coords()
	if node then
		local attrs = M.parse_fetch_block(node)
		print(vim.inspect(attrs))
		-- attrs now is a table like:
		-- { owner = "pete3n", repo = "ninjection.nvim", rev = " ", hash = "sha256-GyXyIgZ3mdCVH4/7suRRN9+o+hQpDqJoboT69VxKMkY=" }
	end
end

return M
