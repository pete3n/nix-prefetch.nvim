---@alias NixPrefetchSubcommand fun(): nil

---@type table<string, { impl: NixPrefetchSubcommand }>
local subcommand_tbl = {
  update = {
    impl = function()
      require("nix_prefetch").update()
    end,
  },
  update_branch = {
    impl = function()
      vim.ui.input({ prompt = "Enter branch to update with:" }, function(input)
        if not input then
          vim.notify("Branch update cancelled", vim.log.levels.WARN)
          return
        end
        require("nix_prefetch").update({ branch = input })
      end)
    end,
  },
  update_rev = {
    impl = function()
      vim.ui.input({ prompt = "Enter rev to update with:" }, function(input)
        if not input then
          vim.notify("Rev update cancelled", vim.log.levels.WARN)
          return
        end
        require("nix_prefetch").update({ rev = input })
      end)
    end,
	}
}

---@param opts { fargs: string[] }
local function nix_prefetch_cmd(opts)
  local subcommand_key = opts.fargs[1]
  if not subcommand_key or not subcommand_tbl[subcommand_key] then
    local available = table.concat(vim.tbl_keys(subcommand_tbl), ", ")
    vim.notify("NixPrefetch: Unknown subcommand: " .. tostring(subcommand_key)
      .. ". Available subcommands: " .. available, vim.log.levels.ERROR)
    return
  end
  subcommand_tbl[subcommand_key].impl()
end

vim.api.nvim_create_user_command("NixPrefetch", nix_prefetch_cmd, {
  nargs = 1,
  desc = "nix-prefetch.nvim plugin command with subcommand support",
  complete = function(arg_lead)
    return vim.tbl_filter(function(key)
      return key:find(arg_lead, 1, true)
    end, vim.tbl_keys(subcommand_tbl))
  end,
})

---@mod nix_prefetch-command USER COMMAND
---@brief :NixPrefetch <subcommand?>
---
--- Subcommands:
---   update         => nix_prefetch.update()
---   update_branch  => nix_prefetch.update(opts.branch = input)
---   update_rev     => nix_prefetch.update(opts.rev = input)
