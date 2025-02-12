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
      (string_expression) @value
    )
    (#match? @key "^(owner|repo|rev|hash)$")
  ]]
  local query = vim.treesitter.query.parse("nix", query_str)
  local result = {}
  local match_count = 0

  for _, captures, _ in query:iter_matches(fetch_block_node, buf, 0, -1) do
    match_count = match_count + 1

    local key_node, value_node
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
      result[key_text] = value_text
    end
  end

  return result
end

M.get_attrs = function()
  local node = select(1, M.get_cur_blk_coords())
  if node then
		local attrs = M.parse_fetch_block(node)
		return attrs
  else
    print("No fetch block node found.")
  end
end

M.get_repo_info = function(git_info)
  local owner = git_info.owner
  local repo  = git_info.repo
  local url = "https://github.com/" .. owner .. "/" .. repo

  -- Construct the shell command.
  -- Notice that we do not pass a rev argument so that nix-prefetch-git fetches the latest commit.
  local cmd = string.format(
    'nix-prefetch-git --no-deepClone --fetch-submodules %s | jq \'{ rev, hash }\'',
    url
  )
  print("Running command: " .. cmd)

  -- Run the command and capture its output.
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    print("Error running nix-prefetch-git: " .. output)
    return nil
  end

  local result = vim.fn.json_decode(output)
  print("Updated repo info:")
  print(vim.inspect(result))
  return result
end

M.update_repo_info = function()
	local attrs = M.get_attrs()
	if not attrs then
		print("No git attributes found. Aborting update.")
		return nil
	end
  print("Current repo attributes:")
  print(vim.inspect(attrs))

  -- Run nix-prefetch-git (via get_repo_info) to get the updated rev and hash.
  local new_info = M.get_repo_info(attrs)
  if not new_info then
    print("Failed to update repo info.")
    return nil
  end

  print("New repo info received:")
  print(vim.inspect(new_info))
  -- At this point, you could update your file's fetch block with the new rev and hash.
  return new_info
end

return M
