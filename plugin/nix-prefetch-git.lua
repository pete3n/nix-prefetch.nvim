vim.api.nvim_create_user_command("NPGGetAttrs", require("nix-prefetch-git").get_attrs, {})
