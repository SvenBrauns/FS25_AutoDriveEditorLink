-- Fakes of AutoDrive's vehicle data: advd for every vehicle, ad.stateModule for drivable ones.
local markerObjects = {}
local function marker(index)
    markerObjects[index] = markerObjects[index] or {markerIndex = index}
    return markerObjects[index]
end

local function vehicle(uniqueId, options)
    local v = {farm = options.farm or 1, attacher = options.attacher, spec_attachable = options.attachable}
    v.advd = {park = options.park or -1}
    function v.advd:getParkDestination(target) return target.advd.park end
    function v.advd:setParkDestination(target, park)
        target.advd.park = park
        local root = target.attacher or target
        if root.ad ~= nil then
            root.ad.stateModule.jobPark = park
        end
    end
    if options.drivable then
        local state = {jobPark = options.park or -1, driverName = options.driverName or ""}
        state.firstMarker = options.first and {markerIndex = options.first} or nil
        state.secondMarker = options.second and {markerIndex = options.second} or nil
        function state:getParkDestinationAtJobFinished() return self.jobPark end
        function state:setParkDestinationAtJobFinished(park) self.jobPark = park end
        function state:getFirstMarker() return self.firstMarker end
        function state:getFirstMarkerId() return self.firstMarker.markerIndex end
        function state:setFirstMarker(id) self.firstMarker = marker(id) end
        function state:getSecondMarker() return self.secondMarker end
        function state:getSecondMarkerId() return self.secondMarker.markerIndex end
        function state:setSecondMarker(id) self.secondMarker = marker(id) end
        function state:getName() return self.driverName end
        v.ad = {stateModule = state}
    end
    function v:getUniqueId() return uniqueId end
    function v:getOwnerFarmId() return self.farm end
    function v:getFullName() return "Name " .. uniqueId end
    function v:getAttacherVehicle() return self.attacher end
    return v
end

test("vehicles: remap keeps unlisted numbers and replaces deleted ones", function()
    local markers = {[2] = 0, [3] = 2}
    eq(ADELVehicles.remap(markers, 1, -1), 1, "unlisted")
    eq(ADELVehicles.remap(markers, 2, -1), -1, "deleted")
    eq(ADELVehicles.remap(markers, 3, -1), 2, "moved")
    eq(ADELVehicles.remap(markers, -1, 1), -1, "none")
end)

test("vehicles: after a reload targets and parking positions follow their markers", function()
    local tractor = vehicle("t", {drivable = true, first = 3, second = 2, park = 5})
    local tool = vehicle("i", {attachable = true, attacher = tractor, park = 2})
    local markers = {[2] = 0, [3] = 2, [5] = 4}

    local changed = ADELVehicles.moveMarkers({tractor, tool}, markers)

    eq(changed, 2, "changed")
    eq(tractor.advd.park, 4, "tractor park")
    eq(tool.advd.park, -1, "tool park deleted")
    eq(tractor.ad.stateModule.jobPark, 4, "job end park of the tractor, not of the tool")
    eq(tractor.ad.stateModule.firstMarker, marker(2), "first target moved, new object")
    eq(tractor.ad.stateModule.secondMarker, marker(1), "deleted second target goes to marker 1")
end)

test("vehicles: unchanged markers still get the new marker objects", function()
    local tractor = vehicle("t", {drivable = true, first = 7})
    ADELVehicles.moveMarkers({tractor}, {})
    eq(tractor.ad.stateModule.firstMarker, marker(7), "first")
end)

test("vehicles: list shows farm vehicles and implements, not trains or pallets", function()
    local tractor = vehicle("a", {drivable = true, driverName = "Vario", park = 4})
    local tool = vehicle("b", {attachable = true, attacher = tractor})
    local wagon = vehicle("c", {attachable = true, farm = 0})
    local pallet = vehicle("d", {})

    local list = ADELVehicles.list({tool, wagon, pallet, tractor}, function(v) return "x.xml" end)

    eq(#list, 2, "count")
    eq(list[1].uniqueId, "a", "tractor")
    eq(list[1].driverName, "Vario", "driver")
    eq(list[1].park, 4, "park")
    eq(list[2].attachedTo, "a", "attached")
    eq(list[2].filename, "x.xml", "filename")
end)

test("vehicles: park sets implements first and names the vehicles not found", function()
    local tractor = vehicle("a", {drivable = true})
    local tool = vehicle("b", {attachable = true, attacher = tractor})

    local count, missing = ADELVehicles.park({tractor, tool}, {a = 6, b = 9, gone = 1})

    eq(count, 2, "count")
    eq(tool.advd.park, 9, "tool")
    eq(tractor.advd.park, 6, "tractor")
    eq(tractor.ad.stateModule.jobPark, 6, "job end park is the tractor's own")
    eq(#missing, 1, "missing")
    eq(missing[1], "gone", "missing id")
end)

test("vehicles: marker 0 removes the parking position", function()
    local tool = vehicle("b", {attachable = true, park = 3})
    ADELVehicles.park({tool}, {b = 0})
    eq(tool.advd.park, -1, "park")
end)
