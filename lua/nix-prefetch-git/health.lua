local health = require("vim.health")

local M = {}

function M.check()
  health.start("nix-prefetch-git.nvim Health Check")

  -- Check for external binary: jq
  if vim.fn.executable("jq") == 1 then
    health.ok("jq is available in your PATH.")
  else
    health.report_error("jq is not available in your PATH. Please install it.")
  end

  -- Check for external binary: nix-prefetch-git
  if vim.fn.executable("nix-prefetch-git") == 1 then
    health.ok("nix-prefetch-git is available in your PATH.")
  else
    health.error("nix-prefetch-git is not available in your PATH. Please install it.")
  end

  -- Check for the Treesitter dependency (nvim-treesitter)
  local ok, _ = pcall(require, "nvim-treesitter")
  if ok then
    health.ok("nvim-treesitter is installed.")
  else
    health.error("nvim-treesitter is not installed. Please install it.")
  end
end

return M
