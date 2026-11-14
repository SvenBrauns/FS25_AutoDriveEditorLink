-- The vehicles' AutoDrive markers: list them, set parking positions, and move targets and parking
-- positions along after a reload. Works on the vehicles given, so the tests can pass fakes.
--
-- AutoDrive keeps per vehicle: ad.stateModule (drivable vehicles) with the target markers as marker
-- objects (firstMarker, secondMarker) and the parking position for the end of a job as a number;
-- advd (all vehicles) with the vehicle's own parking position as a number, saved in vehicles.xml.
ADELVehicles = {}

-- The number a marker has after a reload: unchanged if not listed, `deleted` if listed as 0.
function ADELVehicles.remap(markers, number, deleted)
    if number == nil or number < 1 then
        return number
    end
    local new = markers[number]
    if new == nil then
        return number
    end
    return new == 0 and deleted or new
end

-- The vehicles' marker numbers before a reload. Read before the upload: after it AutoDrive points
-- the targets to the marker on the same node id, which the editor's renumbered nodes make wrong.
function ADELVehicles.readMarkers(vehicles)
    local old = {}
    for _, vehicle in pairs(vehicles) do
        local entry = {}
        local state = vehicle.ad ~= nil and vehicle.ad.stateModule or nil
        if state ~= nil then
            entry.jobPark = state:getParkDestinationAtJobFinished()
            entry.first = state:getFirstMarker() ~= nil and state:getFirstMarkerId() or nil
            entry.second = state:getSecondMarker() ~= nil and state:getSecondMarkerId() or nil
        end
        if vehicle.advd ~= nil then
            entry.park = vehicle.advd:getParkDestination(vehicle)
        end
        old[vehicle] = entry
    end
    return old
end

-- After a reload, whose new marker list replaced the old one. old: from readMarkers before it;
-- markers: number before -> number now (0: deleted), see FORMAT.md. The targets are set anew in
-- any case. A deleted target becomes marker 1 and a deleted parking position none, as when a
-- marker is deleted in the game. Parking positions are set first: setting one also sets the job
-- end parking position of the vehicle it hangs on. Returns the number of parking positions moved.
function ADELVehicles.moveMarkers(old, markers)
    local changed = 0
    for vehicle, entry in pairs(old) do
        local park = ADELVehicles.remap(markers, entry.park, -1)
        if park ~= entry.park then
            vehicle.advd:setParkDestination(vehicle, park)
            changed = changed + 1
        end
    end
    for vehicle, entry in pairs(old) do
        local state = vehicle.ad ~= nil and vehicle.ad.stateModule or nil
        if state ~= nil then
            if entry.jobPark ~= nil and entry.jobPark >= 1 then
                state:setParkDestinationAtJobFinished(ADELVehicles.remap(markers, entry.jobPark, -1))
            end
            if entry.first ~= nil and entry.first >= 1 then
                state:setFirstMarker(ADELVehicles.remap(markers, entry.first, 1))
            end
            if entry.second ~= nil and entry.second >= 1 then
                state:setSecondMarker(ADELVehicles.remap(markers, entry.second, 1))
            end
        end
    end
    return changed
end

-- Whether AutoDrive can park the vehicle: it has AutoDrive data, belongs to a farm (not trains)
-- and is drivable by AutoDrive or attachable (not pallets).
local function canPark(vehicle)
    return vehicle.advd ~= nil and vehicle:getOwnerFarmId() ~= 0
        and (vehicle.ad ~= nil or vehicle.spec_attachable ~= nil)
end

-- The vehicles AutoDrive can park, as tables for result.xml. filename(vehicle) gives the vehicle
-- XML as vehicles.xml names it.
function ADELVehicles.list(vehicles, filename)
    local list = {}
    for _, vehicle in pairs(vehicles) do
        if canPark(vehicle) then
            local attacher = vehicle.getAttacherVehicle ~= nil and vehicle:getAttacherVehicle() or nil
            local state = vehicle.ad ~= nil and vehicle.ad.stateModule or nil
            table.insert(list, {
                uniqueId = vehicle:getUniqueId(),
                filename = filename(vehicle),
                name = vehicle:getFullName(),
                driverName = state ~= nil and state:getName() or "",
                attachedTo = attacher ~= nil and attacher:getUniqueId() or "",
                park = vehicle.advd:getParkDestination(vehicle),
            })
        end
    end
    table.sort(list, function(a, b) return a.uniqueId < b.uniqueId end)
    return list
end

-- Sets the parking positions: parks maps unique id -> marker number (0: none). Implements first, so
-- a vehicle's own parking position ends up as its job end parking position. Returns the number set
-- and the unique ids not found.
function ADELVehicles.park(vehicles, parks)
    local found, missing = {}, {}
    local ordered = {}
    for _, vehicle in pairs(vehicles) do
        if canPark(vehicle) and parks[vehicle:getUniqueId()] ~= nil then
            found[vehicle:getUniqueId()] = true
            table.insert(ordered, vehicle)
        end
    end
    table.sort(ordered, function(a, b)
        local aRoot, bRoot = a.ad ~= nil, b.ad ~= nil
        if aRoot ~= bRoot then
            return bRoot
        end
        return a:getUniqueId() < b:getUniqueId()
    end)
    for _, vehicle in ipairs(ordered) do
        local marker = parks[vehicle:getUniqueId()]
        vehicle.advd:setParkDestination(vehicle, marker > 0 and marker or -1)
    end
    for uniqueId in pairs(parks) do
        if not found[uniqueId] then
            table.insert(missing, uniqueId)
        end
    end
    table.sort(missing)
    return #ordered, missing
end
