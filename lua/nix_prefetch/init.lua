---@module "nix_prefetch"
---@brief
--- Prefetch module provides primary nix-prefetch functions
local nix_prefetch = {}
local parse  = require("nix_prefetch.parse")
local types = require("nix_prefetch.types") -- adjust path if needed
local GitForge = types.GitForge

if vim.fn.exists(":checkhealth") == 2 then
	require("nix_prefetch.health").check()
end

local cfg = require("nix_prefetch.config").values

---@private
---@param git_info GitTriplet
---@return string? url, string? err
local function _create_url(git_info)
	---@type string
	local protocol = "https://"
	---@type string
	local url = protocol .. git_info.forge .. "/" .. git_info.owner .. "/" .. git_info.repo

	return url, nil
end

---@private
---@param attrs_dict table<string, string>
---@return GitTriplet? git_info, string? err
local function _create_git_info(attrs_dict)
	---@type string, string
	local owner, repo
	---@type string, string
	for key, val in pairs(attrs_dict) do
		if key == "owner" then
			owner = val
		elseif key == "repo" then
			repo = repo
		end
	end

	if not owner and repo then
		---@type string
		local err = "nix_prefetch._create_git_info(): error repo or owner attributes not found."
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return nil, err
	end

	---@type GitTriplet
	local git_info = {
		forge = GitForge.GITHUB,
		owner = owner,
		repo = repo,
	}

	return git_info, nil
end

-- We need to pull the current repo to check for updated rev and hash info
---@private
---@param git_info GitTriplet
---@param opts? table
---@param callback fun(result: table<string, any>?): nil
function nix_prefetch._prefetch_git(git_info, opts, callback)
	---@type string?
	local url, url_err = _create_url(git_info)
	if not url then
		---@type string
		local err = "nix_prefetch.prefetch_git() error: Could not create URL ... " .. tostring(url_err)
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return nil, err
	end

	---@type table
	opts = opts or {}

	---@type string[]
	local cmd = {
		"nix-prefetch-git",
	}

	if opts.deepClone == false then
		table.insert(cmd, "--no-deepClone")
	end
	if opts.fetchSubmodules ~= false then
		table.insert(cmd, "--fetch-submodules")
	end
	if opts.rev then
		table.insert(cmd, "--rev")
		table.insert(cmd, "refs/heads/" .. opts.rev)
	end

	table.insert(cmd, url)

	vim.system(cmd, { text = true, timeout = cfg.timeout or 5000
 }, function(obj)
		if obj.code ~= 0 then
			vim.notify("nix-prefetch-git failed for " .. url, vim.log.levels.ERROR)
			callback(nil)
			return
		end

		local ok, parsed = pcall(vim.json.decode, obj.stdout)
		if not ok then
			vim.notify("Failed to decode nix-prefetch-git output", vim.log.levels.ERROR)
			callback(nil)
			return
		end

		callback(parsed)
	end)
end

---@param opts? table
---@return boolean updated, string? err
function nix_prefetch.update(opts)
  opts = opts or {}

  ---@type NPNodePair?, string?
  local node_pair, np_err = parse.get_node_pair()
  if not node_pair then
    local err = "nix_prefetch.update() warning: Could not update ... " .. tostring(np_err)
    if cfg.debug then
      vim.notify(err, vim.log.levels.WARN)
    end
    return false, err
  end

	---@type integer
  local bufnr = node_pair.node_with_range.bufnr
	---@type NPRange
  local range = node_pair.node_with_range.range
	---@type GitTriplet?
  local git_info = _create_git_info(node_pair.attrs_dict)

	if not git_info then
		---@type string
		local err = "nix_prefetch.update() error: Could not retrieve git info."
		if cfg.debug then
			vim.notify(err, vim.log.levels.ERROR)
		end
		return false, err
	end

  -- Optional: notify start
  vim.notify("Fetching latest revision and hash...", vim.log.levels.INFO)

	vim.notify("DEBUG: bufnr " .. bufnr)
	vim.notify("DEBUG: range " .. vim.inspect(range))
	vim.notify("DEBUG: git_info " .. vim.inspect(git_info))

  -- Start async git prefetch
  nix_prefetch._prefetch_git(git_info, opts, function(result)
    if not result then
      vim.notify("nix-prefetch-git failed to retrieve update info.", vim.log.levels.ERROR)
      return
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      vim.notify("Buffer is no longer valid, cannot apply update.", vim.log.levels.WARN)
      return
    end

    -- Format updated lines
    local new_lines = {}
    for k, v in pairs(result) do
      if k == "rev" or k == "hash" then
        table.insert(new_lines, string.format('  %s = "%s";', k, v))
      end
    end

    -- Replace range in buffer
    vim.schedule(function()
      vim.api.nvim_buf_set_lines(bufnr, range.s_row, range.e_row + 1, false, new_lines)
      vim.notify("Nix prefetch updated: rev=" .. result.rev .. ", sha256=" .. result.sha256, vim.log.levels.INFO)
    end)
  end)

  return true, nil
end

return nix_prefetch
