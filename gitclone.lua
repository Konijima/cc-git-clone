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
    for i=1, #files do
        local function download()
            local filePath = fs.combine(localRepoPath, files[i].path)

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

            term.setCursorPos(x, y)
            term.clearLine()
            downloadedCount = downloadedCount + 1
            local progressText = 'Receiving files:  ' .. (downloadedCount / #files * 100) .. '% (' .. downloadedCount .. '/' .. #files .. ')'
            if downloadedCount ~= #files then
                term.write(progressText)
            else
                print(progressText)
            end
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
    for module, path, url in content:gmatch('%[submodule "(.-)"%][^%[]-path = (.-)\n[^%[]-url = (.-)\n') do
        table.insert(modules, {path = path, url = url})
    end

    return modules
end

local function cloneSubmodules(modules)
    for _, module in ipairs(modules) do
        local submodulePath = fs.combine(localPath, repo, module.path)
        local user, submoduleRepo = module.url:match('https://github.com/(.-)/([^.]+)')
        local submoduleBranch = 'master'  -- Assuming 'master' as default branch
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
                    table.insert(files, { path = module.path .. '/' .. entry.path, url = url, binary = entry.type == "blob" })
                end
            end
            print('Cloning submodule into ' .. submodulePath .. '...')
            clone(files)
        else
            printError(reason)
        end
    end
end

local res, reason = http.get(treeUrl)
if not reason then
    if fs.exists(localRepoPath) then
        fs.delete(localRepoPath)
    end

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
            table.insert(files, { path = entry.path, url = url, binary = entry.type == "blob" })
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
