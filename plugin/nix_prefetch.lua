vim.api.nvim_create_user_command("NPUpdate", function()
  require("nix_prefetch").update()
end, {})

vim.api.nvim_create_user_command("NPUpdateBranch", function()
  vim.ui.input({
    prompt = "Enter branch to update from:",
    default = "",
  }, function(input)
    if input == nil or input == "" then
      vim.notify("NPUpdateBranch cancelled or empty", vim.log.levels.WARN)
      return
    end

    local ok, result = pcall(function()
      local success, err = require("nix_prefetch").update({ branch = input })
      if not success then
        vim.notify("Update failed: " .. (err or "unknown error"), vim.log.levels.ERROR)
      end
    end)

    if not ok then
      vim.notify("Unexpected error in NPUpdateBranch: " .. tostring(result), vim.log.levels.ERROR)
    end
  end)
end, {
  desc = "Prompt and run nix_prefetch.update() with branch option",
})
