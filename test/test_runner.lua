-- test_runner.lua
-- Runs all SubMerge test scripts.
-- Usage: luajit test/test_runner.lua

local tests = {
    "test_basic.lua",
    "test_dropdowns.lua",
    "test_merge_logic.lua",
    "test_merge_output.lua",
    "test_primary_selection.lua",
    "test_overwrite.lua",
    "test_edge_cases.lua",
}

local passed = 0
local failed = 0

print("=== SubMerge Test Suite ===\n")

for _, test in ipairs(tests) do
    local path = "test/" .. test
    local f = io.open(path, "r")
    if not f then
        print("SKIP: " .. test .. " (not found)")
        goto continue
    end
    f:close()

    print("Running: " .. test)
    local ok, err = pcall(function()
        dofile(path)
    end)
    if ok then
        print("  PASSED\n")
        passed = passed + 1
    else
        print("  FAILED: " .. tostring(err) .. "\n")
        failed = failed + 1
    end

    ::continue::
end

print(string.format("=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
    os.exit(1)
end
