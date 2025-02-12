vim.api.nvim_create_user_command("NPGUpdateRepo", require("nix-prefetch-git").update_repo_info, {})

