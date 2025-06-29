---@module "nix_prefetch.parse"
---@brief
--- Parsing functions for nix_prefetch

local parse = {}
local cfg = require("nix_prefetch.config").values

---@private
--- Parse queries for fetch blocks.
--- TODO: Add support for other git sources
---@return vim.treesitter.Query? query, string? err
local function _get_fetch_query()
	---@type vim.treesitter.Query, string?
	local query, qry_err = vim.treesitter.query.parse("nix", cfg.queries.fetch_from_github)
	if not query then
		---@type string
		local err = "prefetch.parse.get_attrs() warning: Failed to parse fetchFromGitHub ... " .. tostring(qry_err)
		if cfg.debug then
			vim.notify(err, vim.log.levels.WARN)
		end
		return nil, err
	end

	return query, nil
end

---@private
--- Get the treesitter node at the cursor position
---@return NPNodeWithRange? node_with_range, string? err
local function _get_node_at_cursor()
	---@type boolean, integer?
	local bufnr_ok, cur_bufnr = pcall(vim.api.nvim_get_current_buf)
	if not bufnr_ok then
		---@type string
		local err = "nix_prefetch.parse._get_node_at_cursor() error: Could not retrieve current bufnr ... "
			.. tostring(cur_bufnr)
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return nil, err
	end
	---@cast cur_bufnr integer

	---@type boolean, integer[]?
	local cursor_ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
	if not cursor_ok then
		---@type string
		local err = "nix_prefetch.parse._get_node_at_cursor() error: "
			.. "Could not retrieve cursor position for current window ... "
			.. tostring(cursor)
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return nil, err
	end
	---@cast cursor integer[]

	---@type integer
	local cur_row = cursor[1] - 1 -- convert to 0-indexed
	---@type integer
	local cur_col = cursor[2]

	---@type vim.treesitter.Query?, string?
	local query, attrs_err = _get_fetch_query()
	if not query then
		return nil, tostring(attrs_err)
	end
	---@cast query vim.treesitter.Query

	---@type vim.treesitter.LanguageTree?, string? parse_err
	local parser, parse_err = vim.treesitter.get_parser(cur_bufnr, "nix")
	if not parser then
		---@type string
		local err = "prefetch.parse.get_node_at_cursor() error: No parser available for nix ... " .. tostring(parse_err)
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return nil, err
	end
	---@cast parser vim.treesitter.LanguageTree

	---@type TSTree?
	local tree = parser:parse()[1]
	if not tree then
		---@type string
		local err = "nix_prefetch.get_node_at_cursor() error: Could not parse first language tree."
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return nil, err
	end
	---@cast tree TSTree
	---@type TSNode
	local root = tree:root()

	---@type integer, TSNode
	for id, node, _ in query:iter_captures(root, cur_bufnr, 0, -1) do
		---@type string
		local capture_name = query.captures[id]
		if capture_name == "fetchBlock" then
			---@type integer
			local s_row, s_col, e_row, e_col = node:range()
			if
				(cur_row > s_row or (cur_row == s_row and cur_col >= s_col))
				and (cur_row < e_row or (cur_row == e_row and cur_col <= e_col))
			then
				---@type NPNodeWithRange
				local node_with_range = {
					bufnr = cur_bufnr,
					node = node,
					range = { s_row = s_row, s_col = s_col, e_row = e_row, e_col = e_col },
				}
				return node_with_range, nil
			end
		end
	end

	---@type string
	local err = "prefetch.parse.get_node_at_cursor() warning: No node found."
	if cfg.debug then
		vim.notify(err, vim.log.levels.WARN)
	end

	return nil
end

---@private
--- Parses a Nix attribute set from a Treesitter node to a Lua dictionary.
---@param fetch_node TSNode
---@return table<string, string>? , string? err
local function _get_attrs_dict(fetch_node)
	---@type integer
	local buf = vim.api.nvim_get_current_buf()
	---@type table<string, string>
	local attrs_dict = {}

	---@type vim.treesitter.Query?
	local query = vim.treesitter.query.parse("nix", cfg.queries.attrs)
	if not query then
		---@type string
		local err = "prefetch.parse._get_attrs_dict() warning: Could not parse attributes."
		if cfg.debug then
			vim.notify(err, vim.log.levels.WARN)
		end
		return nil, err
	end
	---@cast query vim.treesitter.Query

	vim.notify("Children of fetch_node:")
	for i = 0, fetch_node:child_count() - 1 do
		local c = fetch_node:child(i)
		local c_type = c and c:type() or "nil"
		local c_text = vim.treesitter.get_node_text(c, buf)
		vim.notify(string.format("  [%d] type = %s, text = %s", i, c_type, vim.inspect(c_text)))
	end

	---@type integer
	local match_count = 0
	---@type table<integer, TSNode[]>
	for _, captures, _ in query:iter_matches(fetch_node, buf, 0, -1) do
		match_count = match_count + 1
		vim.notify("Match #" .. match_count)

		---@type TSNode, TSNode
		local key_node, value_node
		---@type integer, TSNode
		for id, node in pairs(captures) do
			---@type string
			local capture_name = query.captures[id]
			local node_type = node and vim.treesitter.get_node_type(node) or "nil"
			local node_text = "<invalid>"
			local range_info = "<invalid>"

			if node then
				local ok, text_or_err = pcall(vim.treesitter.get_node_text, node, buf)
				if ok then
					node_text = text_or_err
				end

				local ok_range, srow, scol = pcall(function()
					local sr, sc, _, _ = node:range()
					return sr, sc
				end)

				if ok_range then
					range_info = string.format("[%d, %d]", srow, scol)
				end
			end

			vim.notify(
				string.format(
					"  Capture[%d] = %s\n    Type = %s\n    Text = %s\n    Range = %s",
					id,
					capture_name or "nil",
					node_type,
					vim.inspect(node_text),
					range_info
				)
			)

			if node and capture_name == "key" then
				key_node = node
			elseif node and capture_name == "value" then
				value_node = node
			end
		end

		if key_node and key_node.range and value_node and value_node.range then
			---@type string
			local key_text = vim.trim(vim.treesitter.get_node_text(key_node, buf))
			---@type string
			local value_text = vim.trim(vim.treesitter.get_node_text(value_node, buf))
			value_text = value_text:gsub('^"(.*)"$', "%1")
			attrs_dict[key_text] = value_text
		end
	end

	if next(attrs_dict) ~= nil then
		return attrs_dict, nil
	else
		---@type string
		local err = "nix_prefetch.parse._get_attrs_dict() warning: No valid git attributes found."
		if cfg.debug then
			vim.notify(err, vim.log.levels.WARN)
		end
		return nil, err
	end
end

---@tag parse.get_node_pair()
---@brief
--- Get the attribute set as a Lua dictionary
---
---@return NPNodePair? node_pair, string? err
function parse.get_node_pair()
	---@type NPNodeWithRange?, string?
	local node_with_range, get_nr_err = _get_node_at_cursor()

	if not node_with_range then
		---@type string
		local err = "nix_prefetch.parse.get_node_pair() warning: No fetch node found." .. tostring(get_nr_err)
		if cfg.debug then
			vim.notify(err, vim.log.levels.WARN)
		end
		return nil, err
	end
	---@cast node_with_range NPNodeWithRange

	---@type table<string, string>?
	local attrs_dict = _get_attrs_dict(node_with_range.node)
	if not attrs_dict or attrs_dict == {} then
		---@type string
		local err = "nix_prefetch.parse.get_node_pair() warning: No attribute sets found."
		if cfg.debug then
			vim.notify(err, vim.log.levels.WARN)
		end
	end
	---@cast attrs_dict table<string, string>

	---@type NPNodePair
	local node_pair = {
		node_with_range = node_with_range,
		attrs_dict = attrs_dict,
	}

	return node_pair
end

return parse
