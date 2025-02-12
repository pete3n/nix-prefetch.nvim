local health = require("vim.health")

local M = {}

function M.checkhealth()
  health.report_start("nix-prefetch-git.nvim Health Check")

  -- Check for external binary: jq
  if vim.fn.executable("jq") == 1 then
    health.report_ok("jq is available in your PATH.")
  else
    health.report_error("jq is not available in your PATH. Please install it.")
  end

  -- Check for external binary: nix-prefetch-git
  if vim.fn.executable("nix-prefetch-git") == 1 then
    health.report_ok("nix-prefetch-git is available in your PATH.")
  else
    health.report_error("nix-prefetch-git is not available in your PATH. Please install it.")
  end

  -- Check for the Treesitter dependency (nvim-treesitter)
  local ok, _ = pcall(require, "nvim-treesitter")
  if ok then
    health.report_ok("nvim-treesitter is installed.")
  else
    health.report_error("nvim-treesitter is not installed. Please install it.")
  end
end

return M
