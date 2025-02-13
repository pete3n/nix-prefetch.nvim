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
        rev = "44496fb3e706c795e87d475d674708919a01cbea";
        hash = "sha256-tSDIGbTD+5fm1Qo3922DGJ1YIRNAUJF2btWf4kWbCoM=";
      };
    })
  ];
```
This will register the NGUpdateRepo command which you can keybind.
If you call NGUpdateRepo with the cursor in a fetchFromGitHub attribute set, 
then it will check for the most recent revision, and if it is different from the
current, updates the revision and the corresponding hash.

## Future Development
- [x] fetchFromGitHub: update rev and hash
    - [ ] fetchFromGithub: preserve rev, update hash
    - [ ] sha256 attribute support
    - [ ] version tag interpretation/support
- [ ] fetchFromGitLab support
- [ ] fetchurl support 
- [ ] fetchzip support 
