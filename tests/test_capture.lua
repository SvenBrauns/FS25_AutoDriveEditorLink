-- A fake game: records calls, a clock the test moves, files as a set.
local function fakeGame()
    local game = {calls = {}, files = {}, clock = 100, renderSec = 1, groundY = 50}
    local function record(name, ...)
        table.insert(game.calls, table.concat({name, ...}, " "))
    end
    function game:createFolder(path) record("folder", path) end
    function game:prepare() record("prepare") end
    function game:restore() record("restore") end
    function game:moveCamera(x, z, altitude)
        record("move", x, z, altitude)
        return self.groundY
    end
    function game:render(path)
        record("render", path)
        self.clock = self.clock + self.renderSec
        return self.renderOk ~= false
    end
    function game:writeMarker(path)
        record("marker", path)
        self.files[path] = true
    end
    function game:fileExists(path) return self.files[path] == true end
    function game:now() return self.clock end
    function game:writeResult(id, status, message, tiles)
        record("result", id, status)
        self.result = {id = id, status = status, message = message, tiles = tiles}
    end
    return game
end

local function request(n)
    local tiles = {}
    for i = 1, n do
        table.insert(tiles, {col = i, row = 7, x = i * 500, z = -400})
    end
    return {id = 17, pictures = {res = 2000, mode = "raw", altitude = 150, waitMs = 500,
        firstWaitMs = 3000, tiles = tiles}}
end

-- Moves the clock by sec and runs one frame.
local function frame(capture, game, sec)
    game.clock = game.clock + sec
    capture:update()
end

local function count(game, prefix)
    local n = 0
    for _, call in ipairs(game.calls) do
        if call:sub(1, #prefix) == prefix then
            n = n + 1
        end
    end
    return n
end

test("capture: waits firstWaitMs, then waitMs in real time", function()
    local game = fakeGame()
    local c = ADELCapture.new(game, request(2), "ex/")
    c:start()
    eq(game.calls[1], "folder ex/pictures_17/", "folder")
    eq(game.calls[2], "prepare", "prepare")
    eq(game.calls[3], "move 500 -400 150", "first move")
    frame(c, game, 2.9)
    eq(count(game, "render"), 0, "renders before 3 s")
    frame(c, game, 0.2)
    eq(count(game, "render"), 1, "renders after 3 s")
    -- The render took 1 s, the next frame comes right after: no wait has passed yet.
    frame(c, game, 0.02)
    eq(count(game, "render"), 1, "second tile waits")
    frame(c, game, 0.5)
    eq(count(game, "render"), 2, "second tile after 0.5 s")
end)

test("capture: tile files, markers and result", function()
    local game = fakeGame()
    local c = ADELCapture.new(game, request(2), "ex/")
    c:start()
    frame(c, game, 3)
    frame(c, game, 0.5)
    eq(game.calls[4], "render ex/pictures_17/tile_1_7.dds", "first picture")
    eq(game.calls[5], "marker ex/pictures_17/tile_1_7.done", "marker after picture")
    eq(game.calls[#game.calls - 1], "restore", "restore before result")
    eq(game.calls[#game.calls], "result 17 done", "result")
    eq(c.status, "done", "status")
    eq(#game.result.tiles, 2, "result tiles")
    local t = game.result.tiles[2]
    eq(t.col, 2, "col")
    eq(t.groundY, 50, "groundY")
    eq(t.renderSec, 1, "renderSec")
    eq(t.waitSec, 0.5, "waitSec")
    frame(c, game, 5)
    eq(count(game, "render"), 2, "nothing after the end")
end)

test("capture: cancel file stops after the current tile", function()
    local game = fakeGame()
    local c = ADELCapture.new(game, request(3), "ex/")
    c:start()
    game.files["ex/cancel_17"] = true
    frame(c, game, 3)
    eq(c.status, "cancelled", "status")
    eq(count(game, "render"), 1, "renders")
    eq(count(game, "restore"), 1, "restore")
    eq(game.result.status, "cancelled", "result")
    eq(#game.result.tiles, 1, "finished tiles")
end)

test("capture: failed render restores and reports an error", function()
    local game = fakeGame()
    game.renderOk = false
    local c = ADELCapture.new(game, request(2), "ex/")
    c:start()
    frame(c, game, 3)
    eq(c.status, "error", "status")
    eq(count(game, "restore"), 1, "restore")
    assert(game.result.message:find("tile_1_7"), game.result.message)
end)

test("capture: error in prepare still restores", function()
    local game = fakeGame()
    function game:prepare() error("no camera", 0) end
    local c = ADELCapture.new(game, request(1), "ex/")
    c:start()
    eq(c.status, "error", "status")
    eq(count(game, "restore"), 1, "restore")
    eq(game.result.message, "no camera", "message")
end)

test("capture: failing restore is reported", function()
    local game = fakeGame()
    function game:restore() error("camera gone", 0) end
    local c = ADELCapture.new(game, request(1), "ex/")
    c:start()
    frame(c, game, 3)
    eq(game.result.status, "error", "status")
    assert(game.result.message:find("camera gone"), game.result.message)
end)

test("capture: abort while running restores once", function()
    local game = fakeGame()
    local c = ADELCapture.new(game, request(2), "ex/")
    c:start()
    c:abort("map unloaded")
    c:abort("again")
    eq(count(game, "restore"), 1, "restore")
    eq(game.result.message, "map unloaded", "message")
end)

test("capture: progress counts finished tiles", function()
    local game = fakeGame()
    local c = ADELCapture.new(game, request(3), "ex/")
    c:start()
    frame(c, game, 3)
    local done, total = c:progress()
    eq(done, 1, "done")
    eq(total, 3, "total")
end)

test("capture: restored day time is the old time plus the time the capture took", function()
    local hour = 60 * 60 * 1000
    eq(ADELCapture.restoredDayTime(8 * hour, 12 * hour, 13 * hour), 9 * hour, "one hour later")
    eq(ADELCapture.restoredDayTime(23 * hour, 12 * hour, 14 * hour), 1 * hour, "past midnight")
    eq(ADELCapture.restoredDayTime(8 * hour, 23 * hour, 1 * hour), 10 * hour, "capture over midnight")
end)
