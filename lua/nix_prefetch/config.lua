---@module "nix_prefetch.config"

local M = {}

---@tag default_config
local default_config = {
	debug = true,
	timeout = 5000,
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

		attrs = [[
		(binding
			(attrpath (identifier) @key)
			(string_expression) @value
		)
		(#match? @key "^(owner|repo|rev|hash)$")
		]],

		repo = [[
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
