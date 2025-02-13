vim.api.nvim_create_user_command("NPUpdateRepo", require("nix-prefetch").update_repo_info, {})

