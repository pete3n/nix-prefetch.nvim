# nix-prefetch.nvim

_This is a story about Pete_

_Pete loves Nix_ ❤️  <img src="assets/nix.png" alt="Icon" style="width: 16px; height: auto;">

_Pete likes to write Nix using Neovim_  <img src="assets/neovim.png" alt="Icon" style="width: 16px; height: auto;">

_This is what happens to Pete_:
- _Pete commits changes his project repo._
- _Pete wants to build and test his changes but must update the git revision and hash for Nix first._
- _Pete doesn't use Nix well, so he just erases the old hash, and rebuilds, 
then copies the hash-mismatch error message and pastes it back into his config, then rebuilds again._
- _Pete does this alot <img src="assets/alot.png" alt="Icon" style="width: 16px; height: auto;">
because he is bad at developing software._

_Don't be like Pete, use nix-prefetch.nvim!_

## Current Support
nix-prefetch.nvim is currently limited to fetchFromGitHub attribute sets using a rev
and hash value (See [Future Development](#Future-Development) for planned features). As an example of a
supported format, this is the code block to include nix-prefetch.nvim in your Nixvim config:
```
  extraPlugins = [
    (pkgs.vimUtils.buildVimPlugin {
      name = "nix-prefetch.nvim";
      src = pkgs.fetchFromGitHub {
        owner = "pete3n";
        repo = "nix-prefetch.nvim";
				rev = "4f32441c3a7f550ccb8cbd73cba8ab11aa32f8d1";
        hash = "sha256-FpUYNdyn3YrbrAWdkyeE7Kl/ThmSKBNl1l2ePjznKRc=";
      };
    })
  ];
```
This will register the NGUpdateRepo command which you can keybind.
If you call NGUpdateRepo with the cursor in a fetchFromGitHub attribute set, 
then it will check for the most recent revision, and if it is different from the
current, updates the revision and the corresponding hash.

## Dependencies
- neovim v0.11+ 
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) must be installed.
- nix-prefetch-git must be executable and available in your path. 

To confirm dependencies are availabe, nix-prefetch includes a health check function 
that you can run from the nvim commandline with:
```
    :checkhealth nix_prefetch
```

## Future Development
- [x] fetchFromGitHub
- [x] fetchFromGitLab
- [x] update default branch to latest rev 
- [x] update from user specified rev
- [x] update from user specified branch to latest rev
- [ ] nix-repl.nvim eval integration
