-- Reads request.xml (see FORMAT.md). get(key) returns the string at a game XML key or nil, so the
-- parser runs on the game's XML functions in the game and on plain tables in the tests.
ADELRequest = {}
ADELRequest.FORMAT = "1"

local NUMBERS = {"mPerPx", "res", "altitude", "waitMs", "firstWaitMs", "dayTime"}
local STRINGS = {"mode", "weather"}

-- Returns the request table, or nil, an error message and the id (if it could be read).
function ADELRequest.parse(get)
    local id = tonumber(get("request#id"))
    local format = get("request#format")
    if format ~= ADELRequest.FORMAT then
        return nil, string.format("request format %s not supported, please update the mod", tostring(format)), id
    end
    if id == nil then
        return nil, "request without id"
    end
    local request = {id = id, type = get("request#type"), map = get("request#map"),
        savegame = tonumber(get("request#savegame"))}
    if request.type ~= "pictures" then
        return nil, "unknown request type " .. tostring(request.type), id
    end
    if request.map == nil or request.savegame == nil then
        return nil, "request without map or savegame", id
    end

    local pictures = {tiles = {}}
    for _, name in ipairs(NUMBERS) do
        pictures[name] = tonumber(get("request.pictures#" .. name))
        if pictures[name] == nil then
            return nil, "pictures#" .. name .. " missing or not a number", id
        end
    end
    for _, name in ipairs(STRINGS) do
        pictures[name] = get("request.pictures#" .. name)
        if pictures[name] == nil then
            return nil, "pictures#" .. name .. " missing", id
        end
    end

    local i = 0
    while true do
        local key = string.format("request.pictures.tile(%d)", i)
        if get(key .. "#col") == nil then
            break
        end
        local tile = {col = tonumber(get(key .. "#col")), row = tonumber(get(key .. "#row")),
            x = tonumber(get(key .. "#x")), z = tonumber(get(key .. "#z"))}
        if tile.col == nil or tile.row == nil or tile.x == nil or tile.z == nil then
            return nil, string.format("tile %d needs numbers col, row, x, z", i), id
        end
        table.insert(pictures.tiles, tile)
        i = i + 1
    end
    if #pictures.tiles == 0 then
        return nil, "request without tiles", id
    end
    request.pictures = pictures
    return request
end
