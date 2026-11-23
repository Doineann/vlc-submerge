-- test_edge_cases.lua
-- Tests: no video playing, 0 / 1 subtitle files (dropdowns hidden),
--        2+ subtitle files (dropdowns shown).

local H = dofile("test/helpers.lua")

local function has_text(dlg, needle)
    for _, lbl in ipairs(dlg.labels) do
        if lbl.text:find(needle, 1, true) then return true end
    end
    return false
end

local function count_dropdowns(dlg)
    local n = 0
    for _ in pairs(dlg.dropdowns) do n = n + 1 end
    return n
end

H.reset_tmp()

-- Test 1: no video playing.
print("  Test 1: no video playing")
H.setup()
H.load()
local ok, err = pcall(activate)
assert(ok, "activate should not error without video: " .. tostring(err))
local dlg = H.dlg()
assert(dlg, "dialog should exist")
assert(count_dropdowns(dlg) == 0, "no dropdowns without video")
assert(has_text(dlg, "No local video is currently playing."),
    "should show the no-video message")
assert(H.button(dlg, "Refresh"), "should offer a Refresh button")
print("    No video: message + Refresh, no dropdowns: OK")

-- Test 2: video playing, 0 subtitle files.
print("  Test 2: video with 0 subtitle files")
H.setup({ video = H.video_uri() })
H.load()
ok, err = pcall(activate)
assert(ok, "activate should not error with 0 subtitles: " .. tostring(err))
dlg = H.dlg()
assert(count_dropdowns(dlg) == 0, "no dropdowns when fewer than 2 subtitles")
assert(has_text(dlg, "Need at least 2 matching SRT files to merge."),
    "should show the requirement message")
assert(H.button(dlg, "Refresh"), "should offer a Refresh button")
print("    0 subtitles: requirement message, no dropdowns: OK")

-- Test 3: video playing, 1 subtitle file.
print("  Test 3: video with 1 subtitle file")
H.write(H.srt("test.en.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hello"))
H.setup({ video = H.video_uri() })
H.load()
ok, err = pcall(activate)
assert(ok, "activate should not error with 1 subtitle: " .. tostring(err))
dlg = H.dlg()
assert(count_dropdowns(dlg) == 0, "no dropdowns with only 1 subtitle")
assert(has_text(dlg, "Number of subtitle files found: 1"),
    "should report the single file count")
assert(H.button(dlg, "Refresh"), "should offer a Refresh button")
print("    1 subtitle: requirement message, no dropdowns: OK")

-- Test 4: video playing, 2+ subtitle files -> dropdowns appear.
print("  Test 4: video with 2 subtitle files")
H.write(H.srt("test.nl.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hallo"))
H.setup({ video = H.video_uri() })
H.load()
ok, err = pcall(activate)
assert(ok, "activate should not error with 2 subtitles: " .. tostring(err))
dlg = H.dlg()
assert(dlg.dropdowns.first_sub, "first_sub dropdown should exist")
assert(dlg.dropdowns.second_sub, "second_sub dropdown should exist")
assert(H.button(dlg, "Merge and load"), "should offer a Merge and load button")
print("    2 subtitles: dropdowns and Merge button appear: OK")

H.cleanup()

print("\nALL EDGE CASE TESTS PASSED")
