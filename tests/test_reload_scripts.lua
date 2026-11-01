-- adelReloadScripts: the main script runs a second time in the same environment.
test("reload scripts: listener added once, state kept, commands added again", function()
    local listeners, added, removed = 0, {}, {}
    g_currentModName, g_currentModDirectory = "FS25_AutoDriveEditorLink", ""
    getUserProfileAppPath = function() return "" end
    addModEventListener = function() listeners = listeners + 1 end
    addConsoleCommand = function(name) table.insert(added, name) end
    removeConsoleCommand = function(name) table.insert(removed, name) end
    source = dofile
    AutoDriveEditorLink = nil

    dofile("scripts/AutoDriveEditorLink.lua")
    local adel = AutoDriveEditorLink
    adel:addConsoleCommands()
    adel.revision = 41
    g_currentModName, g_currentModDirectory = nil, nil -- not set while a console command runs
    local message = adel:consoleReloadScripts()

    assert(message:find("reloaded"), message)
    eq(AutoDriveEditorLink, adel, "same table")
    eq(listeners, 1, "listeners")
    eq(adel.revision, 41, "revision")
    eq(adel.modName, "FS25_AutoDriveEditorLink", "modName")
    eq(#removed, #added / 2, "removed")
    eq(added[#added], "adelReloadScripts", "last command")
end)

test("reload scripts: not during a capture", function()
    local adel = AutoDriveEditorLink
    adel.capture = {}
    assert(adel:consoleReloadScripts():find("capture"))
    adel.capture = nil
end)
