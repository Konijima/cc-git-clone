local expect = dofile("rom/modules/main/cc/expect.lua").expect

local args = {...}

expect(1, args[1], 'string')
expect(1, args[2], 'string')
expect(1, args[3], 'string')

local treeUrl = 'https://api.github.com/repos/[USER]/[REPO]/git/trees/[BRANCH]?recursive=1'
local rawFileUrl = 'https://raw.githubusercontent.com/[USER]/[REPO]/[BRANCH]/[PATH]'

local user = args[1]
local repo = args[2]
local branch = args[3]
local localPath = args[4] or shell.dir()

local localRepoPath = fs.combine(localPath, repo)

treeUrl = treeUrl:gsub('%[USER]', user)
treeUrl = treeUrl:gsub('%[REPO]', repo)
treeUrl = treeUrl:gsub('%[BRANCH]', branch)

local function clone(files)
    local processes = {}
    local x, y = term.getCursorPos()

    local downloadedCount = 0

    local function step_progress(leading_text)
        term.setCursorPos(x, y)
        term.clearLine()
        downloadedCount = downloadedCount + 1
        local progressText = leading_text .. ': ' .. (downloadedCount / #files * 100) .. '% (' .. downloadedCount .. '/' .. #files .. ')'
        if downloadedCount ~= #files then
            term.write(progressText)
        else
            print(progressText)
        end
    end

    for i=1, #files do
        local function download()
            local filePath = fs.combine(localRepoPath, files[i].path)

            if fs.exists(filePath) then
                if fs.getSize(filePath) == files[i].size then
                    step_progress('Checking files')
                    return
                end
            end

            local request = http.get(files[i].url, nil, files[i].binary)
            local content = request.readAll()
            request.close()

            local mode = 'w'
            if files[i].binary then
                mode = 'wb'
            end

            local writer = fs.open(filePath, mode)
            writer.write(content or '')
            writer.close()
            step_progress('Receiving files')
        end
        table.insert(processes, download)
    end
    parallel.waitForAll(table.unpack(processes))
end

local function parseGitModules()
    local gitModulesPath = fs.combine(localPath, repo, '.gitmodules')
    if not fs.exists(gitModulesPath) then
        return {}
    end

    local file = fs.open(gitModulesPath, 'r')
    local content = file.readAll()
    file.close()

    local modules = {}
    for module, path, url in content:gmatch('%[submodule "(.-)"%]%s*path = ([^\n]+)%s*url = ([^\n]+)') do
        table.insert(modules, {path = path, url = url})
    end

    return modules
end

local function cloneSubmodule(module)
    local submodulePath = fs.combine(localPath, repo, module.path)
    local submodule_name = fs.getName(module.path)

    -- Check if submodule already exists
    if fs.exists(submodulePath) then
        --print('Submodule ' .. submodule_name .. ' already exists, skipping.')
        return
    end
    local user, submoduleRepo, submoduleBranch = '', '', ''

    -- Get user and repo.
    if module.url:match('^https://') then
        user, submoduleRepo = module.url:match('https://github.com/(.-)/([^/]+)%.git$')
        if not submoduleRepo then
            user, submoduleRepo = module.url:match('https://github.com/(.-)/([^/]+)')
        end
    elseif module.url:match('^git@') then
        user, submoduleRepo = module.url:match('git@github.com:(.-)/([^/]+)%.git$')
        if not submoduleRepo then
            user, submoduleRepo = module.url:match('git@github.com:(.-)/([^/]+)')
        end
    end

    -- Get default branch.
    local checkBranchUrl = 'https://api.github.com/repos/' .. user .. '/' .. submoduleRepo
    local branchRes, branchReason = http.get(checkBranchUrl)
    if branchRes then
        local repoInfo = textutils.unserialiseJSON(branchRes.readAll())
        if repoInfo.default_branch then
            submoduleBranch = repoInfo.default_branch
        end
        branchRes.close()
    else
        printError('Failed to fetch repository info: ' .. (branchReason or 'Unknown error'))
        return
    end

    if user == '' or submoduleRepo == '' then
        printError('Failed to parse user and repo from URL: ' .. module.url)
        return
    elseif submoduleBranch == '' then
        printError('Failed to parse branch from URL: ' .. module.url)
        return
    end

    local submoduleTreeUrl = 'https://api.github.com/repos/' .. user .. '/' .. submoduleRepo .. '/git/trees/' .. submoduleBranch .. '?recursive=1'
    local submoduleRawFileUrl = 'https://raw.githubusercontent.com/' .. user .. '/' .. submoduleRepo .. '/' .. submoduleBranch .. '/[PATH]'

    local res, reason = http.get(submoduleTreeUrl)
    if not reason then
        local tree = res.readAll()
        tree = textutils.unserialiseJSON(tree)
        local files = {}
        for k, entry in pairs(tree.tree) do
            if entry.type ~= "tree" and entry.type ~= "commit" then
                local url = submoduleRawFileUrl:gsub('%[PATH]', entry.path)
                table.insert(files, { path = module.path .. '/' .. entry.path, url = url, binary = entry.type == "blob", size = entry.size })
            end
        end
        print('Cloning submodule ' .. submodule_name .. '...')
        clone(files)
    else
        printError(reason)
    end
end

local function cloneSubmodules(modules)
    for _, module in ipairs(modules) do
        cloneSubmodule(module)
    end
end

local res, reason = http.get(treeUrl)
if not reason then
    local tree = res.readAll()
    tree = textutils.unserialiseJSON(tree)
    local files = {}
    for k, entry in pairs(tree.tree) do
        if entry.type ~= "tree" and entry.type ~= "commit" then
            local url = rawFileUrl
            url = url:gsub('%[USER]', user)
            url = url:gsub('%[REPO]', repo)
            url = url:gsub('%[BRANCH]', branch)
            url = url:gsub('%[PATH]', entry.path)
            table.insert(files, { path = entry.path, url = url, binary = entry.type == "blob", size = entry.size })
        end
    end
    print('Cloning into ' .. repo .. '...')
    clone(files)

    -- Handle submodules
    local modules = parseGitModules()
    cloneSubmodules(modules)
else
    printError(reason)
end
