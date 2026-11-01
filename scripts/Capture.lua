-- One picture capture: a state machine driven by update() each frame, no blocking waits.
-- Waits are measured with now() (real time), not by adding up dt: the frame after a render has a
-- dt of about a second, which would end the next wait at once.
-- Per tile: move the camera, wait, render an uncompressed DDS (~0.1 s; a PNG takes ~1.4 s to encode),
-- write the .done marker, check for cancel.
-- Everything that touches the game goes through `game` (AutoDriveEditorLink.lua; a fake in the tests):
--   prepare(pictures)              hide HUD, light, distance factors, ortho camera
--   moveCamera(x, z, altitude)     returns groundY
--   render(path, res, mode)        returns true on success
--   writeMarker(path), fileExists(path), createFolder(path), now() (seconds)
--   restore()                      camera, HUD, distance factors; must cope with a half-done prepare
--   writeResult(id, status, message, tiles)
ADELCapture = {}
ADELCapture.__index = ADELCapture

-- dir: exchange folder with trailing slash.
function ADELCapture.new(game, request, dir)
    local self = setmetatable({}, ADELCapture)
    self.game, self.request, self.dir = game, request, dir
    self.folder = string.format("%spictures_%d/", dir, request.id)
    self.cancelPath = string.format("%scancel_%d", dir, request.id)
    self.index, self.wait = 0, 0
    self.done = {} -- per finished tile: col, row, groundY, waitSec, renderSec
    self.status = nil -- "done" | "cancelled" | "error" once finished
    return self
end

function ADELCapture:start()
    local ok, err = pcall(function()
        self.game:createFolder(self.folder)
        self.game:prepare(self.request.pictures)
        self:moveTo(1)
    end)
    if not ok then
        self:finish("error", tostring(err))
    end
end

function ADELCapture:update()
    if self.status ~= nil then
        return
    end
    local ok, err = pcall(self.step, self)
    if not ok then
        self:finish("error", tostring(err))
    end
end

-- For the on-screen line: tiles finished, tiles total.
function ADELCapture:progress()
    return #self.done, #self.request.pictures.tiles
end

-- Ends a running capture from outside (map unloaded).
function ADELCapture:abort(message)
    if self.status == nil then
        self:finish("error", message)
    end
end

function ADELCapture:moveTo(index)
    local pictures = self.request.pictures
    local tile = pictures.tiles[index]
    self.index = index
    self.wait = (index == 1 and pictures.firstWaitMs or pictures.waitMs) / 1000
    self.groundY = self.game:moveCamera(tile.x, tile.z, pictures.altitude)
    self.movedAt = self.game:now()
end

function ADELCapture:step()
    if self.game:now() - self.movedAt < self.wait then
        return
    end
    local pictures = self.request.pictures
    local tile = pictures.tiles[self.index]
    local name = string.format("tile_%d_%d", tile.col, tile.row)
    local renderStart = self.game:now()
    if not self.game:render(self.folder .. name .. ".dds", pictures.res, pictures.mode) then
        error("renderScreenshot failed for " .. name, 0)
    end
    table.insert(self.done, {col = tile.col, row = tile.row, groundY = self.groundY,
        waitSec = renderStart - self.movedAt, renderSec = self.game:now() - renderStart})
    self.game:writeMarker(self.folder .. name .. ".done")

    if self.game:fileExists(self.cancelPath) then
        self:finish("cancelled")
    elseif self.index == #pictures.tiles then
        self:finish("done")
    else
        self:moveTo(self.index + 1)
    end
end

-- Restores the game first (also when something broke), then writes the result.
function ADELCapture:finish(status, message)
    self.status = status
    local ok, err = pcall(self.game.restore, self.game)
    if not ok then
        status = "error"
        message = (message and message .. "; " or "") .. "restore failed: " .. tostring(err)
        self.status = status
    end
    self.game:writeResult(self.request.id, status, message or "", self.done)
end
