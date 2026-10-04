local config = require("modules/utils/config")
local utils = require("modules/utils/utils")

---@class manager
---@field projects project[]
---@field updateList interaction[]
---@field mod mod?
local manager = {
    projects = {},
    updateList = {},
    mod = nil
}

function manager.init(mod)
    manager.mod = mod

    for _, file in pairs(dir("projects")) do
        if file.name:match("^.+(%..+)$") == ".json" then
            local entry = require("modules/classes/project"):new(mod)
            entry:load(config.loadFile(string.format("projects/%s", file.name)))
            table.insert(manager.projects, entry)
        end
    end

    manager.rebuildUpdateList()
end

---Rebuilds the list of interactions on which onUpdate is called
function manager.rebuildUpdateList()
    local list = {}

    for _, project in pairs(manager.projects) do
        if project.enabled then
            for _, interaction in pairs(project.interactions) do
                if interaction.needsUpdate then
                    table.insert(list, interaction)
                end
            end
        end
    end

    manager.updateList = list
end

local playerPosition = { x = 0, y = 0, z = 0 }

function manager.update()
    local list = manager.updateList
    local nUpdates = #list
    if nUpdates == 0 then return end

    local position = GetPlayer():GetWorldPosition()
    playerPosition.x = position.x
    playerPosition.y = position.y
    playerPosition.z = position.z

    -- [CET-Cleans] distance gate: interactions near V update every frame as before; far ones
    -- (outside max(80 m, their own reset/animation distance + 10 m)) update once a second, staggered.
    local now = os.clock()
    local px, py, pz = playerPosition.x, playerPosition.y, playerPosition.z
    for i = 1, nUpdates do
        local it = list[i]
        local r = it._cleanNearSq
        if not r then
            local d = math.max(80, (it.resetDistance or 0) + 10, (it.animationDistance or 0) + 10)
            r = d * d
            it._cleanNearSq = r
            it._cleanNext = now + (i % 30) / 30 -- spread far updates over one second
        end
        local near = false
        local p = it.worldIconPosition
        if p then
            local dx, dy, dz = p.x - px, p.y - py, p.z - pz
            near = dx * dx + dy * dy + dz * dz < r
        else
            near = true
        end
        local e = it.apartmentEntrancePosition
        if not near and e and (e.x ~= 0 or e.y ~= 0) then
            local dx, dy, dz = e.x - px, e.y - py, e.z - pz
            near = dx * dx + dy * dy + dz * dz < r
        end
        if near or now >= it._cleanNext then
            it._cleanNext = now + 1.0
            it:onUpdate(playerPosition)
        end
    end
end

function manager.sessionStart()
    for _, project in pairs(manager.projects) do
        project:sessionStart()
    end
end

function manager.sessionEnd()
    for _, project in pairs(manager.projects) do
        project:sessionEnd()
    end
end

---@param name string
---@param ignore project?
---@return boolean
local function isNameTaken(name, ignore)
    if ignore and ignore.name == name then return false end

    for _, project in pairs(manager.projects) do
        if project ~= ignore and project.name == name then
            return true
        end
    end

    return false
end

---@param name string
---@param ignore project?
---@return string
function manager.getUniqueName(name, ignore)
    local unique = name
    local suffix = 1

    while isNameTaken(unique, ignore) do
        suffix = suffix + 1
        unique = string.format("%s_%d", name, suffix)
    end

    return unique
end

function manager.addProject(project)
    table.insert(manager.projects, project)
    manager.rebuildUpdateList()
end

---@param data project
function manager.removeProject(data)
    for _, interaction in pairs(data.interactions) do
        interaction:remove()
    end
    utils.removeItem(manager.projects, data)
    manager.rebuildUpdateList()
end

function manager.shutdown()
    for _, project in pairs(manager.projects) do
        for _, interaction in pairs(project.interactions) do
            interaction:remove()
        end
    end

    manager.updateList = {}
end

return manager