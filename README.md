# cc-git-clone
ComputerCraft program to clone a git repo.

## Install
```lua
wget https://raw.githubusercontent.com/Konijima/cc-git-clone/master/gitclone.lua
```

## Clone Repo
```lua
--- PARAMS:
--- USER, Required, git username
--- REPO, Required, git repo name
--- BRANCH, Required, git repo branch to clone
--- PATH, Optional, local path to save the repo inside, if omitted will clone into the current working directory
gitclone <USER> <REPO> <BRANCH> <PATH>
```

## Exemples
Exemple 1:
```lua
-- Command
gitclone Konijima cc-git-clone master
-- Result directory
/cc-radio-player/
```
Exemple 2:
```lua
-- Command
gitclone Konijima cc-git-clone master /programs
-- Result directory
/programs/cc-radio-player/
```
