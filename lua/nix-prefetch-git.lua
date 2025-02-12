if vim.fn.exists(":checkhealth") == 2 then
	require("nix-prefetch-git.health").check()
end

local M = {}

M.cfg = {
	ts_qry_github_str = [[
		(apply_expression
			(select_expression
				(attrpath (identifier) @fetchName
					(#eq? @fetchName "fetchFromGitHub"))
			)
			(attrset_expression) @fetchBlock
		)
	]],

	ts_qry_git_attrs_str = [[
    (binding
      (attrpath (identifier) @key)
      (string_expression) @value
    )
    (#match? @key "^(owner|repo|rev|hash)$")
  ]],

	ts_qry_origin_repo_str = [[
    (binding
      (attrpath (identifier) @key)
      (string_expression) @value
    )
    (#match? @key "^(rev|hash)$")
  ]],

	timeout = 5000,
}

-- Locate available github attribute sets
-- TODO: Add support for other git sources
M.ts_query_github_attrs = function()
	local query = vim.treesitter.query.parse("nix", M.cfg.ts_qry_github_str)
	if not query then
		print("Failed to parse fetchFromGitHub")
		return nil
	end
	return query
end

-- We need to identify the attribute set to modify based on the cursor location
-- Only modify an attribute set if the cursor falls in its range
M.get_cur_blk_coords = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cur_row = cursor[1] - 1 -- convert to 0-indexed
	local cur_col = cursor[2]

	local query = M.ts_query_github_attrs()
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

-- We need to parse the attributes for the Github set and format them to JSON
M.parse_fetch_block = function(fetch_block_node)
  local buf = vim.api.nvim_get_current_buf()
  local query = vim.treesitter.query.parse("nix", M.cfg.ts_qry_git_attrs_str)
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
    print("No fetchFromGithub attribute sets found.")
  end
end

-- We need to pull the current repo to check for updated rev and hash info
M.get_repo_info = function(git_info)
  local owner = git_info.owner
  local repo  = git_info.repo
  local url = "https://github.com/" .. owner .. "/" .. repo

  local cmd = string.format(
    'nix-prefetch-git --no-deepClone --fetch-submodules %s 2>/dev/null | jq \'{ rev, hash }\'',
    url
  )

	local output_lines = {}
  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          table.insert(output_lines, line)
        end
      end
    end,
  })

  local ret = vim.fn.jobwait({ job_id }, M.cfg.timeout)
  if ret[1] == -1 then
		vim.fn.jobstop(job_id)
    print("Error: nix-prefetch-git command timed out after " .. M.cfg.timeout .. "ms.")
    return nil
	elseif ret[1] ~= 0 then
    print("Error running nix-prefetch-git or timed out:")
    print(table.concat(output_lines, "\n"))
    return nil
  end

	local output = table.concat(output_lines, "\n")
	if output == "" then
		print("No output from nix-prefetch-git.")
    return nil
  end

  -- In case extra output exists, extract the JSON substring.
  local json_start = output:find("{")
  local json_end = output:find("}", json_start)
  if json_start and json_end then
    output = output:sub(json_start, json_end)
	else
		print("Failed to locate JSON output in command response.")
		return nil
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
    print("fetchFromGithub attributes not found.")
    return
  end

  local current_attrs = M.parse_fetch_block(node)
  if not current_attrs then
    print("Could not parse attributes.")
    return
  end
	
	-- Don't update values if they are already current
	if current_attrs.rev == new_info.rev and current_attrs.hash == new_info.hash then
		print(current_attrs.owner .. "/" .. current_attrs.repo .. " -- rev and hash already latest.")
		return
	end

  local buf = bufnr
  local query = vim.treesitter.query.parse("nix", M.cfg.ts_qry_origin_repo_str)

  for _, captures, _ in query:iter_matches(node, buf, 0, -1) do
    for i, cap in ipairs(captures) do
      local capture_name = query.captures[i]
      if capture_name == "key" then
        local key_text = vim.trim(vim.treesitter.get_node_text(cap, buf))
        if key_text == "rev" or key_text == "hash" then
					local value_node = nil
          for j, cap_node in ipairs(captures) do
            if query.captures[j] == "value" then
              value_node = cap_node
            end
          end
          if value_node then
            local s_row, s_col, e_row, e_col = value_node:range()
            local new_val = new_info[key_text]  -- new_info.rev or new_info.hash
            -- Surround the new value with quotes.
            new_val = '"' .. new_val .. '"'
            -- Update the buffer.
            vim.api.nvim_buf_set_text(buf, s_row, s_col, e_row, e_col, { new_val })
          end
        end
      end
    end
  end
  print("Updated " .. attrs.owner .. "/" .. attrs.repo .. " rev and hash")
end

return M
