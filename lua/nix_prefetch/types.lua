---@module "nix_prefetch.types"

---@tag NPConfig
---@brief Store nix_prefetch configuration data.
---
---@class NPConfig
---@field debug boolean -- Provide debug notifications.
---@field timeout integer -- Timeout in ms for nix-prefetch command to execute.
---@field queries table<string, table<string, string>> -- Groups treesitter queries into
--- tables by type of query.
---@field query_metadata table<string, any> -- Metadata to store specific params
--- for transforming parsed queries.

---@tag NPRange
---@class NPRange
---@brief Store range4 position coordinates.
---
---@field s_row integer
---@field s_col integer
---@field e_row integer
---@field e_col integer

---@tag NPFetchNode
---@class NPFetchNode
---@brief Store treesitter node, its parent bufnr, and its associated range.
---
---@field bufnr integer
---@field node TSNode
---@field range NPRange
---@field query_name string

---@tag NPNodeTuple
---@class NPNodePair
---@brief Core class that stores the bufnr, TSNode information, and the
--- associated key:value pairs for its Nix attribute set.
---
---@field fetch_node NPFetchNode
---@field attrs_dict table<string, string>

---@alias GitForgeType
---| "github.com"
---| "gitlab.com"

---@class GitForge
---@field GITHUB GitForgeType
---@field GITLAB GitForgeType
local GitForge = {
	GITHUB = "github.com",
	GITLAB = "gitlab.com",
}

---@tag GitTriplet
---@class GitTriplet
---@brief Contains forge, owner, and repo information for git.
---@field forge GitForgeType
---@field owner string
---@field repo string

---@tag PrefetchGit
---@class PrefetchGit
---@brief Parameters to pass to nix-prefetch-git
---@field url string -- Any URL understood by 'git clone'
---@field rev string? -- Any sha1 or reference (such as refs/heads/master)

---@class NPUpdateOpts
---@field branch? string
---@field rev? string
---@field fetchSubmodules? boolean
---@field deepClone? boolean

return {
	GitForge = GitForge,
}
