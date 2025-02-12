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
	timeout = 5000,
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

  -- Build the command without providing a rev so that nix-prefetch-git
  -- fetches the latest commit. We redirect stderr to /dev/null to suppress
  -- non-JSON output.
  local cmd = string.format(
    'nix-prefetch-git --no-deepClone --fetch-submodules %s 2>/dev/null | jq \'{ rev, hash }\'',
    url
  )
  print("Running command: " .. cmd)

  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    print("Error running nix-prefetch-git: " .. output)
    return nil
  end

  -- Optionally, if extraneous output still exists, you can try to extract the JSON substring:
  local json_start = output:find("{")
  local json_end = output:find("}", json_start)
  if json_start and json_end then
    output = output:sub(json_start, json_end)
  end

  local result = vim.fn.json_decode(output)
  return result
end

M.update_repo_info = function()
	local attrs = M.get_attrs()
	if not attrs then
		print("No git attributes found. Aborting update.")
		return nil
	end

  local new_info = M.get_repo_info(attrs)
  if not new_info then
    print("Failed to retrieve updated repo info.")
    return nil
  end

	local bufnr = vim.api.nvim_get_current_buf()
  local node = select (1, M.get_cur_blk_coords())
  if not node then
    print("Fetch block not found.")
    return
  end

  -- Parse the current attributes from the block.
  local current_attrs = M.parse_fetch_block(node)
  if not current_attrs then
    print("Could not parse fetch block attributes.")
    return
  end

  print("Current attributes:")
  print(vim.inspect(current_attrs))
  print("New repo info:")
  print(vim.inspect(new_info))

  -- We'll update only the rev and hash. We need to find their nodes.
  -- You can create a query to match individual bindings in the fetch block.
  local buf = bufnr
  local query_str = [[
    (binding
      (attrpath (identifier) @key)
      (string_expression) @value
    )
    (#match? @key "^(rev|hash)$")
  ]]
  local query = vim.treesitter.query.parse("nix", query_str)

  for _, captures, _ in query:iter_matches(node, buf, 0, -1) do
    for i, cap in ipairs(captures) do
      local capture_name = query.captures[i]
      if capture_name == "key" then
        local key_text = vim.trim(vim.treesitter.get_node_text(cap, buf))
        if key_text == "rev" or key_text == "hash" then
          -- Now get the corresponding value node.
          local value_node = captures[query.captures["value"]]
          -- If that didn't work, iterate to match based on capture index.
          for j, node in ipairs(captures) do
            if query.captures[j] == "value" then
              value_node = node
            end
          end
          if value_node then
            local s, sc, e, ec = value_node:range()
            local new_val = new_info[key_text]  -- new_info.rev or new_info.hash
            -- Surround the new value with quotes.
            new_val = '"' .. new_val .. '"'
            -- Update the buffer.
            vim.api.nvim_buf_set_text(buf, s, sc, e, ec, { new_val })
          end
        end
      end
    end
  end
  print("File updated with new repo info!")
end

return M
