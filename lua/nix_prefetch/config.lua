---@module "nix_prefetch.config"

local types = require("nix_prefetch.types")
local M = {}

---@tag default_config
---@type NPConfig
local default_config = {
	---@type boolean
	debug = true,
	---@type integer
	timeout = 5000,
	---@type table<string, table<string, string>>
	queries = {
		fetch = {
			github = [[
			(apply_expression
				(select_expression
					(attrpath (identifier) @fetchName
						(#eq? @fetchName "fetchFromGitHub"))
				)
				(attrset_expression) @fetchBlock
			)
			]],

			github_direct = [[
      (apply_expression
        function: (variable_expression
          name: (identifier) @fetchName
          (#eq? @fetchName "fetchFromGitHub")
        )
        argument: (attrset_expression) @fetchBlock
      )
			]],

			github_select = [[
      (apply_expression
        function: (select_expression
          (attrpath
            (identifier)
            (identifier) @fetchName
            (#eq? @fetchName "fetchFromGitHub")
          )
        )
        argument: (attrset_expression) @fetchBlock
      )
			]],

			gitlab = [[
      (apply_expression
        function: (variable_expression
          name: (identifier) @fetchName
          (#eq? @fetchName "fetchFromGitLab")
        )
        argument: (attrset_expression) @fetchBlock
      )
			]],

			tarball = [[
      (apply_expression
        function: (variable_expression
          name: (identifier) @fetchName
          (#eq? @fetchName "fetchTarball")
        )
        argument: (attrset_expression) @fetchBlock
      )
			]],
		},
		attrs = {
			all = [[
			(binding
				(attrpath (identifier) @key)
				(string_expression) @value
			)
			(#match? @key "^(owner|repo|rev|hash)$")
			]],

			rev_hash = [[
			(binding
				(attrpath (identifier) @key)
				(string_expression) @value
			)
			(#match? @key "^(rev|hash)$")
			]],

			hash = [[
			(binding
				(attrpath (identifier) @key)
				(string_expression) @value
			)
			(#match? @key "^hash$")
			]],
		}
	},
	---@type table<string, any>
	query_metadata = {
		github = {
			---@type GitForgeType
			forge = types.GitForge.GITHUB
		},
		github_direct = {
			---@type GitForgeType
			forge = types.GitForge.GITHUB
		},
		github_select = {
			---@type GitForgeType
			forge = types.GitForge.GITHUB
		},
		gitlab = {
			---@type GitForgeType
			forge = types.GitForge.GITLAB
		}
	},
}

---@nodoc
------ Fetch current configuration, or default_config
------@return NinjectionConfig
M.get_config = function()
	return M.values or default_config
end

-- Always ensure at least the default_config exists.
M.values = M.values or default_config

return M
