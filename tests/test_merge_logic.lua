-- test_merge_logic.lua
-- Tests: auto-default selection (English primary, different language second)
--        via the add_slave fallback path.

local H = dofile("test/helpers.lua")

H.reset_tmp()
H.write(H.srt("test.en.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hello"))
H.write(H.srt("test.nl.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hallo"))

local loaded_path
H.setup({
    video = H.video_uri(),
    add_subtitle = false,  -- force the add_slave fallback
    add_slave = function(kind, uri)
        loaded_path = uri
        return true
    end,
})
H.load()
activate()

local ok, err = H.click(H.dlg(), "Merge and load")
assert(ok, "merge_selected should not error: " .. tostring(err))
assert(loaded_path, "subtitle should be loaded via add_slave")
assert(loaded_path:find("%.en%-nl%.srt$"),
    "auto-default should merge en with nl, got: " .. tostring(loaded_path))
print("  Auto-default merge: OK -> " .. loaded_path)

H.cleanup()

print("\nALL MERGE LOGIC TESTS PASSED")
