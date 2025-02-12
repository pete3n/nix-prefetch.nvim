# nix-prefetch-git.nvim

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

_Don't be like Pete, use NPG nvim!_

## Future Development
- [x] fetchFromGitHub: update rev and hash
    - [ ] fetchFromGithub: preserve rev, update hash
- [ ] fetchFromGitLab support
- [ ] fetchurl support 
- [ ] fetchzip support 
- [ ]  sha256 attribute support


