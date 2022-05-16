# cc-git-clone
ComputerCraft program to clone a **github** repo.

![](https://github.com/Konijima/cc-git-clone/blob/master/Screenshot_1.png?raw=true)

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
--- PATH, Optional, local path to save the repo inside, default to current working directory
gitclone <USER> <REPO> <BRANCH> <PATH>
```

## Exemples
Exemple 1 (install in current working directory):
```lua
-- Command
gitclone Konijima some-repo master
-- Result directory
/some-repo/
```
Exemple 2: (install in absolute directory)
```lua
-- Command
gitclone Konijima some-repo master /programs
-- Result directory
/programs/some-repo/
```
Example 3: (One liner install)
```lua
-- Command
wget run https://raw.githubusercontent.com/Konijima/cc-git-clone/master/gitclone.lua Konijima some-repo master /programs
-- Result directory
/programs/some-repo/
```
