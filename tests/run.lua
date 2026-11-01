-- Plain-Lua tests (Lua 5.1, like the game). Run from the repository root: lua tests/run.lua
dofile("scripts/Request.lua")
dofile("scripts/Capture.lua")

local tests = {}

-- test("name", function() ... end) registers a test; the files below add theirs.
function test(name, fn)
    table.insert(tests, {name = name, fn = fn})
end

function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

dofile("tests/test_request.lua")
dofile("tests/test_capture.lua")

local failed = 0
for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if not ok then
        failed = failed + 1
        print("FAIL " .. t.name .. ": " .. tostring(err))
    end
end
print(string.format("%d passed, %d failed", #tests - failed, failed))
os.exit(failed == 0 and 0 or 1)
