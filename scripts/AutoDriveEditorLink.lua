-- FS25_AutoDriveEditorLink: the game side of the AutoDrive Editor's exchange folder (FORMAT.md).
-- Each second: write status.xml, and when idle look for a new request.xml.
AutoDriveEditorLink = {}
local ADEL = AutoDriveEditorLink
ADEL.modName = g_currentModName
ADEL.dir = getUserProfileAppPath() .. "modSettings/FS25_AutoDriveEditorLink/"
ADEL.FORMAT = "1"
ADEL.POLL_MS = 1000
-- Distance factors during a capture; adelCoeff changes them. Objects (buildings, trees, terrain) far and
-- detailed; foliage off (0), else its LOD bands draw rings around the camera (they follow ground
-- distance, so a higher camera does not help). The game menu allows 0.5-2.0; the engine takes less.
ADEL.coeffs = {objects = 2.0, foliage = 0}

-- The game's graphics settings that decide how far things are drawn and in how much detail.
local COEFFS = {
    {kind = "objects", get = getViewDistanceCoeff, set = setViewDistanceCoeff},
    {kind = "foliage", get = getFoliageViewDistanceCoeff, set = setFoliageViewDistanceCoeff},
    {kind = "foliage", get = getFoliageLODDistanceCoeff, set = setFoliageLODDistanceCoeff},
    {kind = "objects", get = getLODDistanceCoeff, set = setLODDistanceCoeff},
    {kind = "objects", get = getTerrainLODDistanceCoeff, set = setTerrainLODDistanceCoeff},
}

local function log(fmt, ...)
    print(string.format("AutoDriveEditorLink: " .. fmt, ...))
end

-- The game for ADELCapture (see Capture.lua). `saved` holds what restore() puts back.
local Game = {}

function Game:prepare(pictures)
    local saved = {}
    self.saved = saved
    local mission = g_currentMission
    saved.camera = g_cameraManager:getActiveCamera()
    saved.hud = mission.hud.getIsVisible == nil or mission.hud:getIsVisible()
    mission.hud:setIsVisible(false)
    saved.coeffs = {}
    for i, coeff in ipairs(COEFFS) do
        saved.coeffs[i] = coeff.get()
        coeff.set(ADEL.coeffs[coeff.kind])
    end
    mission.environment:consoleCommandSetDayTime(pictures.dayTime)
    mission.environment.weather:consoleCommandWeatherSet(pictures.weather)

    local cam = createCamera("AutoDriveEditorLinkCamera", math.rad(60), 1, pictures.altitude + 1000)
    saved.cam = cam
    link(getRootNode(), cam)
    setRotation(cam, -math.pi / 2, 0, 0) -- straight down, image top = -z (north)
    setIsOrthographic(cam, true)
    setOrthographicHeight(cam, pictures.res * pictures.mPerPx)
    g_cameraManager:addCamera(cam, nil, false)
    saved.camAdded = true
    g_cameraManager:setActiveCamera(cam)
    local now = {}
    for i, coeff in ipairs(COEFFS) do
        now[i] = string.format("%.3f", coeff.get())
    end
    log("capture prepared: distance factors %s (were %s)", table.concat(now, ", "), table.concat(saved.coeffs, ", "))
end

function Game:restore()
    local saved = self.saved
    self.saved = nil
    if saved == nil then
        return
    end
    if saved.camAdded then
        if saved.camera ~= nil then
            g_cameraManager:setActiveCamera(saved.camera)
        end
        g_cameraManager:removeCamera(saved.cam)
    end
    if saved.cam ~= nil then
        delete(saved.cam)
    end
    for i, value in pairs(saved.coeffs or {}) do
        COEFFS[i].set(value)
    end
    if saved.hud ~= nil then
        g_currentMission.hud:setIsVisible(saved.hud)
    end
end

function Game:moveCamera(x, z, altitude)
    local groundY = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
    setTranslation(self.saved.cam, x, groundY + altitude, z)
    return groundY
end

function Game:render(path, res, mode)
    -- For the hand test: does the game report pending loads when a tile is rendered?
    local pending = #getAllStreamI3DFileRequestIds()
    local ok = renderScreenshot(path, res, res, 1, mode, 0, 0, 0, 0, 0, 3, 12, false)
    log("rendered %s ok=%s, pending I3D loads %d, paused %s", path, tostring(ok), pending,
        tostring(g_currentMission.paused))
    return ok
end

function Game:writeMarker(path)
    local file = createFile(path, FileAccess.WRITE)
    if file == 0 then
        error("cannot write " .. path, 0)
    end
    delete(file)
end

function Game:fileExists(path)
    return fileExists(path)
end

function Game:createFolder(path)
    createFolder(path)
end

function Game:now()
    return getTimeSec()
end

-- result_<id>.xml, then the empty result_<id>.done last.
function Game:writeResult(id, status, message, tiles, reload)
    local xml = createXMLFile("ADELResult", string.format("%sresult_%d.xml", ADEL.dir, id), "result")
    setXMLString(xml, "result#format", ADEL.FORMAT)
    setXMLInt(xml, "result#id", id)
    setXMLString(xml, "result#status", status)
    setXMLString(xml, "result#message", message)
    if reload ~= nil then
        setXMLInt(xml, "result.reload#nodes", reload.nodes)
        setXMLInt(xml, "result.reload#markers", reload.markers)
        setXMLInt(xml, "result.reload#groups", reload.groups)
        setXMLFloat(xml, "result.reload#readSec", reload.readSec)
        setXMLFloat(xml, "result.reload#uploadSec", reload.uploadSec)
    end
    for i, tile in ipairs(tiles) do
        local key = string.format("result.tile(%d)", i - 1)
        setXMLInt(xml, key .. "#col", tile.col)
        setXMLInt(xml, key .. "#row", tile.row)
        setXMLFloat(xml, key .. "#groundY", tile.groundY)
        setXMLFloat(xml, key .. "#waitSec", tile.waitSec)
        setXMLFloat(xml, key .. "#renderSec", tile.renderSec)
    end
    saveXMLFile(xml)
    delete(xml)
    self:writeMarker(string.format("%sresult_%d.done", ADEL.dir, id))
    log("request %d: %s %s (%d tiles)", id, status, message, #tiles)
end

function ADEL:loadMap()
    createFolder(self.dir)
    local mod = g_modManager:getModByName(self.modName)
    self.modVersion = mod ~= nil and mod.version or "?"
    self.timer, self.revision = 0, 0
    addConsoleCommand("adelCoeff", "Distance factors for captures", "consoleCoeff", self, "objects; foliage")
    addConsoleCommand("adelTestCapture", "Write a request for n x n picture tiles around x z", "consoleTestCapture",
        self, "x; z; n; mPerPx; waitMs")
    addConsoleCommand("adelTestReload", "Load a route file (routeExport) into the running game", "consoleTestReload",
        self, "path")
end

function ADEL:deleteMap()
    if self.capture ~= nil then
        self.capture:abort("map unloaded")
        self.capture = nil
    end
    removeConsoleCommand("adelCoeff")
    removeConsoleCommand("adelTestCapture")
    removeConsoleCommand("adelTestReload")
end

function ADEL:update(dt)
    if self.capture ~= nil then
        self.capture:update()
        if self.capture.status ~= nil then
            self.capture = nil
        end
    end
    self.timer = self.timer + dt
    if self.timer < self.POLL_MS then
        return
    end
    self.timer = 0
    self:writeStatus()
    if self.capture == nil then
        self:checkRequest()
    end
end

function ADEL:draw()
    if self.capture ~= nil then
        local done, total = self.capture:progress()
        renderText(0.02, 0.95, 0.02, string.format("AutoDrive Editor: capturing %d/%d", done, total))
    end
end

-- Written in place each second (the mod cannot rename); a reader that fails to parse tries again.
function ADEL:writeStatus()
    self.revision = self.revision + 1
    local info = g_currentMission.missionInfo
    local xml = createXMLFile("ADELStatus", self.dir .. "status.xml", "status")
    setXMLString(xml, "status#format", self.FORMAT)
    setXMLInt(xml, "status#revision", self.revision)
    setXMLString(xml, "status#modVersion", self.modVersion)
    setXMLString(xml, "status#map", tostring(info.mapId))
    setXMLInt(xml, "status#savegame", info.savegameIndex or 0)
    setXMLString(xml, "status#time", getDate("%Y-%m-%dT%H:%M:%S"))
    saveXMLFile(xml)
    delete(xml)
end

-- Starts a capture for a request.xml whose id is new and has no result yet.
function ADEL:checkRequest()
    local path = self.dir .. "request.xml"
    if not fileExists(path) then
        return
    end
    local xml = loadXMLFile("ADELRequest", path)
    if xml == nil or xml == 0 then
        return
    end
    local request, message, id = ADELRequest.parse(function(key) return getXMLString(xml, key) end)
    delete(xml)
    id = request ~= nil and request.id or id
    if (id or "none") == self.lastId then
        return
    end
    self.lastId = id or "none"
    if id == nil then
        log("ignoring request.xml: %s", message)
        return
    end
    if fileExists(string.format("%sresult_%d.xml", self.dir, id)) then
        return -- answered before, e.g. in an earlier game session
    end
    if request == nil then
        Game:writeResult(id, "error", message, {})
        return
    end
    local info = g_currentMission.missionInfo
    if request.map ~= info.mapId or request.savegame ~= info.savegameIndex then
        Game:writeResult(id, "error", string.format("wrong map: the game has %s, savegame %s", tostring(info.mapId),
            tostring(info.savegameIndex)), {})
        return
    end
    if request.type == "reload" then
        local info, message = self:reload(self.dir .. request.reload.file)
        Game:writeResult(id, info ~= nil and "done" or "error", message or "", {}, info)
        return
    end
    log("request %d: %d tiles", id, #request.pictures.tiles)
    self.capture = ADELCapture.new(Game, request, self.dir)
    self.capture:start()
end

-- Loads a route-format file (root routeExport) into the running game, as the RoutesManager's import
-- does. AutoDrive's functions live in its mod environment FS25_AutoDrive. Returns counts and real
-- times in seconds, or nil and an error message.
function ADEL:reload(path)
    local env = FS25_AutoDrive
    if env == nil or env.AutoDrive == nil or env.AutoDriveRoutesUploadEvent == nil then
        return nil, "AutoDrive not found"
    end
    if not fileExists(path) then
        return nil, "file not found: " .. path
    end
    local start = getTimeSec()
    local xml = loadXMLFile("ADELReload", path)
    if xml == nil or xml == 0 then
        return nil, "cannot read " .. path
    end
    local ok, wayPoints, mapMarkers, groups = pcall(env.AutoDrive.readGraphFromXml, xml, "routeExport")
    delete(xml)
    if not ok then
        return nil, "cannot read the network: " .. tostring(wayPoints)
    end
    -- Counted before the upload: AutoDrive adds its debug markers to the same tables.
    local info = {nodes = #wayPoints, markers = #mapMarkers, groups = 0, readSec = getTimeSec() - start}
    for _ in pairs(groups) do
        info.groups = info.groups + 1
    end
    local read = getTimeSec()
    local sent, message = pcall(env.AutoDriveRoutesUploadEvent.sendEvent, wayPoints, mapMarkers, groups)
    if not sent then
        return nil, "upload failed: " .. tostring(message)
    end
    info.uploadSec = getTimeSec() - read
    log("reloaded %s: %d nodes, %d markers, %d groups, read %.2f s, upload %.2f s", path, info.nodes, info.markers,
        info.groups, info.readSec, info.uploadSec)
    return info
end

-- Hand test without the editor. A bare file name is taken from the exchange folder. The console
-- splits arguments at spaces ("My Games"), so they are joined again.
function ADEL:consoleTestReload(...)
    local path = table.concat({...}, " ")
    if path == "" then
        return "usage: adelTestReload <route file (routeExport): full path or a file name in the exchange folder>"
    end
    if not path:find("[/\\:]") then
        path = self.dir .. path
    end
    local info, message = self:reload(path)
    if info == nil then
        return "AutoDriveEditorLink: reload failed: " .. message
    end
    return string.format("AutoDriveEditorLink: reloaded %d nodes, %d markers, %d groups in %.2f + %.2f s", info.nodes,
        info.markers, info.groups, info.readSec, info.uploadSec)
end

function ADEL:consoleCoeff(objects, foliage)
    self.coeffs.objects = tonumber(objects) or self.coeffs.objects
    self.coeffs.foliage = tonumber(foliage) or self.coeffs.foliage
    return string.format("AutoDriveEditorLink: distance factors for captures: objects %.3f, foliage %.3f",
        self.coeffs.objects, self.coeffs.foliage)
end

-- Hand test without the editor: a request for an n x n block of the real tile grid around x z.
function ADEL:consoleTestCapture(x, z, n, mPerPx, waitMs)
    x, z, n = tonumber(x), tonumber(z), tonumber(n) or 1
    if x == nil or z == nil then
        return "usage: adelTestCapture x z [n=1] [mPerPx=0.25] [waitMs=500]"
    end
    mPerPx, waitMs = tonumber(mPerPx) or 0.25, tonumber(waitMs) or 500
    local res, half = 2000, g_currentMission.terrainSize / 2
    local edge = res * mPerPx
    local col0 = math.floor((x + half) / edge) - math.floor(n / 2)
    local row0 = math.floor((z + half) / edge) - math.floor(n / 2)
    local id = tonumber(getDate("%m%d%H%M%S"))
    local info = g_currentMission.missionInfo

    local xml = createXMLFile("ADELTestRequest", self.dir .. "request.xml", "request")
    setXMLString(xml, "request#format", self.FORMAT)
    setXMLInt(xml, "request#id", id)
    setXMLString(xml, "request#type", "pictures")
    setXMLString(xml, "request#map", tostring(info.mapId))
    setXMLInt(xml, "request#savegame", info.savegameIndex or 0)
    setXMLFloat(xml, "request.pictures#mPerPx", mPerPx)
    setXMLInt(xml, "request.pictures#res", res)
    setXMLString(xml, "request.pictures#mode", "raw")
    setXMLInt(xml, "request.pictures#altitude", 150)
    setXMLInt(xml, "request.pictures#waitMs", waitMs)
    setXMLInt(xml, "request.pictures#firstWaitMs", 3000)
    setXMLInt(xml, "request.pictures#dayTime", 12)
    setXMLString(xml, "request.pictures#weather", "SUN")
    local i = 0
    for row = row0, row0 + n - 1 do
        for col = col0, col0 + n - 1 do
            local key = string.format("request.pictures.tile(%d)", i)
            setXMLInt(xml, key .. "#col", col)
            setXMLInt(xml, key .. "#row", row)
            setXMLFloat(xml, key .. "#x", -half + (col + 0.5) * edge)
            setXMLFloat(xml, key .. "#z", -half + (row + 0.5) * edge)
            i = i + 1
        end
    end
    saveXMLFile(xml)
    delete(xml)
    return string.format("AutoDriveEditorLink: request %d written (%d tiles)", id, i)
end

addModEventListener(ADEL)
