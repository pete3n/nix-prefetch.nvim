vim.api.nvim_create_user_command("NPUpdate", function()
  require("nix_prefetch").update()
end, {})
