-- test_basic.lua
-- Tests: descriptor fields, activate/deactivate, input_changed.

local H = dofile("test/helpers.lua")

H.setup()
H.load()

local desc = descriptor()
assert(desc.title == "SubMerge", "title should be SubMerge")
assert(desc.version == "1.3", "version should be 1.3")
assert(desc.shortdesc == "SubMerge", "shortdesc must be exactly 'SubMerge'")
assert(desc.author == "Doineann", "author should be Doineann")
assert(desc.license == "GPL", "license should be GPL")
assert(desc.capabilities and desc.capabilities[1] == "input-listener",
    "should declare input-listener capability")
print("  descriptor: OK")

local ok, err = pcall(activate)
assert(ok, "activate() should not error without video: " .. tostring(err))
print("  activate() without video: OK")

ok, err = pcall(deactivate)
assert(ok, "deactivate() should not error: " .. tostring(err))
print("  deactivate(): OK")

ok, err = pcall(input_changed)
assert(ok, "input_changed() should not error: " .. tostring(err))
print("  input_changed(): OK")

print("\nALL BASIC TESTS PASSED")
