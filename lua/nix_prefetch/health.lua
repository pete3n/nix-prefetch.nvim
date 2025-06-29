---@module "nix_prefetch.health"
local health = require("vim.health")

local start = health.start
local ok = health.ok
local h_error = health.error

local M = {}

function M.check()
  start("nix-prefetch.nvim Health Check")

  -- Check for external binary: nix-prefetch-git
  if vim.fn.executable("nix-prefetch-git") == 1 then
    ok("nix-prefetch-git is available in your PATH.")
  else
    h_error("nix-prefetch-git is not available in your PATH. Please install it.")
  end

  -- Check for the Treesitter dependency (nvim-treesitter)
  local ts_ok, _ = pcall(require, "nvim-treesitter")
  if ts_ok then
    ok("nvim-treesitter is installed.")
  else
    h_error("nvim-treesitter is not installed. Please install it.")
  end
end

return M
