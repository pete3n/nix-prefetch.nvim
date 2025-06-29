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
---@param fetch_node TSNode
---@return table<string, string>? , string? err
local function _get_attrs_dict(fetch_node)
	local buf = vim.api.nvim_get_current_buf()
	local attrs_dict = {}

	local query = vim.treesitter.query.parse("nix", cfg.queries.attrs)
	if not query then
		local err = "prefetch.parse._get_attrs_dict() warning: Could not parse attributes query."
		if cfg.debug then
			vim.notify(err, vim.log.levels.WARN)
		end
		return nil, err
	end

	if cfg.debug then
		vim.notify("Children of fetch_node:")
		local i = 0
		for child in fetch_node:iter_children() do
			if child and child:type() and vim.treesitter.get_node_text then
				vim.notify(
					string.format(
						"  [%d] type = %s, text = %s",
						i,
						child:type(),
						vim.treesitter.get_node_text(child, buf)
					)
				)
			end
			i = i + 1
		end
	end

	for match_index, captures, _ in query:iter_matches(fetch_node, buf, 0, -1) do
		vim.notify(string.format("🔍 Match #%d", match_index), vim.log.levels.INFO)

		-- Dump raw captures table
		for id, node in pairs(captures) do
			local capture_name = query.captures[id]
			local node_type = node and node:type() or "nil"
			local node_text = node and vim.treesitter.get_node_text(node, buf) or "nil"
			vim.notify(
				string.format(
					"  Capture[%d]: %s → type: %s | text: %s",
					id,
					capture_name or "nil",
					node_type,
					node_text
				),
				vim.log.levels.INFO
			)
		end

		local key_node, value_node
		for id, node in pairs(captures) do
			local capture_name = query.captures[id]
			if node and capture_name == "key" then
				key_node = node
			elseif node and capture_name == "value" then
				value_node = node
			end
		end

		if key_node and value_node then
			local key_text = vim.trim(vim.treesitter.get_node_text(key_node, buf))
			local value_text = vim.trim(vim.treesitter.get_node_text(value_node, buf))
			value_text = value_text:gsub('^"(.*)"$', "%1")
			attrs_dict[key_text] = value_text
			vim.notify(string.format("✅ Parsed pair: %s = %s", key_text, value_text), vim.log.levels.INFO)
		else
			vim.notify("⚠️  Missing key or value node in match", vim.log.levels.WARN)
		end
	end

	if next(attrs_dict) ~= nil then
		if cfg.debug then
			vim.notify("DEBUG: _get_attrs_dict returning:\n" .. vim.inspect(attrs_dict))
		end
		return attrs_dict, nil
	else
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
