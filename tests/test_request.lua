-- A valid request as game XML keys; tests change single keys.
local function sample()
    return {
        ["request#format"] = "1", ["request#id"] = "17", ["request#type"] = "pictures",
        ["request#map"] = "FS25_Thueringen_2_0_16x.SampleModMap", ["request#savegame"] = "1",
        ["request.pictures#mPerPx"] = "0.25", ["request.pictures#res"] = "2000",
        ["request.pictures#mode"] = "raw", ["request.pictures#altitude"] = "150",
        ["request.pictures#waitMs"] = "500", ["request.pictures#firstWaitMs"] = "3000",
        ["request.pictures#dayTime"] = "12", ["request.pictures#weather"] = "SUN",
        ["request.pictures.tile(0)#col"] = "3", ["request.pictures.tile(0)#row"] = "7",
        ["request.pictures.tile(0)#x"] = "-2346", ["request.pictures.tile(0)#z"] = "-406",
        ["request.pictures.tile(1)#col"] = "4", ["request.pictures.tile(1)#row"] = "7",
        ["request.pictures.tile(1)#x"] = "-1846", ["request.pictures.tile(1)#z"] = "-406",
    }
end

local function parse(keys)
    return ADELRequest.parse(function(key) return keys[key] end)
end

test("request: valid pictures request", function()
    local r = parse(sample())
    eq(r.id, 17, "id")
    eq(r.map, "FS25_Thueringen_2_0_16x.SampleModMap", "map")
    eq(r.savegame, 1, "savegame")
    local p = r.pictures
    eq(p.mPerPx, 0.25, "mPerPx")
    eq(p.res, 2000, "res")
    eq(p.mode, "raw", "mode")
    eq(p.altitude, 150, "altitude")
    eq(p.waitMs, 500, "waitMs")
    eq(p.firstWaitMs, 3000, "firstWaitMs")
    eq(p.dayTime, 12, "dayTime")
    eq(p.weather, "SUN", "weather")
    eq(#p.tiles, 2, "tiles")
    eq(p.tiles[2].col, 4, "col")
    eq(p.tiles[2].row, 7, "row")
    eq(p.tiles[2].x, -1846, "x")
    eq(p.tiles[2].z, -406, "z")
end)

test("request: other format asks for an update, keeps the id", function()
    local keys = sample()
    keys["request#format"] = "2"
    local r, message, id = parse(keys)
    eq(r, nil, "request")
    assert(message:find("update"), message)
    eq(id, 17, "id")
end)

test("request: no id", function()
    local keys = sample()
    keys["request#id"] = nil
    local r, message, id = parse(keys)
    eq(r, nil, "request")
    eq(id, nil, "id")
    assert(message:find("id"), message)
end)

test("request: unknown type", function()
    local keys = sample()
    keys["request#type"] = "export"
    local r, message = parse(keys)
    eq(r, nil, "request")
    assert(message:find("export"), message)
end)

test("request: missing map or savegame", function()
    for _, key in ipairs({"request#map", "request#savegame"}) do
        local keys = sample()
        keys[key] = nil
        eq(parse(keys), nil, key)
    end
end)

test("request: missing or bad picture setting names it", function()
    local keys = sample()
    keys["request.pictures#waitMs"] = "soon"
    local r, message = parse(keys)
    eq(r, nil, "request")
    assert(message:find("waitMs"), message)
    keys = sample()
    keys["request.pictures#weather"] = nil
    r, message = parse(keys)
    assert(message:find("weather"), message)
end)

test("request: bad tile names its index", function()
    local keys = sample()
    keys["request.pictures.tile(1)#z"] = nil
    local r, message = parse(keys)
    eq(r, nil, "request")
    assert(message:find("tile 1"), message)
end)

test("request: no tiles", function()
    local keys = sample()
    for key in pairs(sample()) do
        if key:find("tile") then
            keys[key] = nil
        end
    end
    local r, message = parse(keys)
    eq(r, nil, "request")
    assert(message:find("tiles"), message)
end)
