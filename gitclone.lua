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

treeUrl = treeUrl:gsub('%[USER]', user)
treeUrl = treeUrl:gsub('%[REPO]', repo)
treeUrl = treeUrl:gsub('%[BRANCH]', branch)

local function clone(files)
    local processes = {}
    local x, y = term.getCursorPos()
    for i=1, #files do
        local function download()
            local filePath = fs.combine(localPath, files[i].path)
            if fs.exists(filePath) then
                fs.delete(filePath)
            end
            local content = http.get(files[i].url).readAll()
            local writer = fs.open(filePath, 'w')
            writer.write(content)
            writer.close()
            term.setCursorPos(x, y)
            if i < #files then
                term.write('Receiving files:  ' .. (i / #files * 100) .. ' (' .. i .. '/' .. #files .. ')')
            else
                print('Receiving files:  ' .. (i / #files * 100) .. ' (' .. i .. '/' .. #files .. '), done')
            end
        end
        table.insert(processes, download)
    end
    parallel.waitForAll(table.unpack(processes))
end

local res, reason = http.get(treeUrl)
if not reason then
    local tree = res.readAll()
    tree = textutils.unserialiseJSON(tree)
    local files = {}
    for k,entry in pairs(tree.tree) do
        if entry.type ~= "tree" then
            local url = rawFileUrl
            url = url:gsub('%[USER]', user)
            url = url:gsub('%[REPO]', repo)
            url = url:gsub('%[BRANCH]', branch)
            url = url:gsub('%[PATH]', entry.path)
            table.insert(files, { path = fs.combine(repo, entry.path), url = url })
        end
    end
    print('Cloning into ' .. repo .. '...')
    clone(files)
else
    printError(reason)
end
