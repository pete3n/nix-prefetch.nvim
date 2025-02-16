vim.api.nvim_create_user_command("NPUpdateRepo", require("nix-prefetch").update_repo_info, {})
vim.api.nvim_create_user_command("NPUpdateHash", function()
  require("nix-prefetch").update_repo_info(true)
end, {})
