-- test_dropdowns.lua
-- Tests: dropdown ordering (English first, second reversed), stacked layout,
--        labels above their dropdowns, note label.

local H = dofile("test/helpers.lua")

H.reset_tmp()
H.write(H.srt("test.de.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hallo"))
H.write(H.srt("test.en.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hello"))
H.write(H.srt("test.nl.srt"), H.cue("00:00:01,000", "00:00:05,000", "Hallo"))

H.setup({ video = H.video_uri() })
H.load()
activate()

local dlg = H.dlg()
local first = dlg.dropdowns.first_sub.values
local second = dlg.dropdowns.second_sub.values

-- First dropdown: English first, then alphabetical by tag.
assert(#first == 3, "first dropdown should have 3 values, got " .. #first)
assert(first[1] == "en" and first[2] == "de" and first[3] == "nl",
    "first dropdown order should be en, de, nl, got: " .. table.concat(first, ", "))
print("  First dropdown order: " .. table.concat(first, ", ") .. " (English first: OK)")

-- Second dropdown: reverse order, English not first.
assert(#second == 3, "second dropdown should have 3 values, got " .. #second)
assert(second[1] == "nl" and second[2] == "de" and second[3] == "en",
    "second dropdown order should be nl, de, en, got: " .. table.concat(second, ", "))
print("  Second dropdown order: " .. table.concat(second, ", ") .. " (reverse: OK)")
assert(second[1] ~= "en", "English should not be first in second dropdown")
print("  English not first in second dropdown: OK")

-- Stacked layout: both at x=1, first above second.
assert(dlg.dropdowns.first_sub.x == 1, "first dropdown x should be 1")
assert(dlg.dropdowns.second_sub.x == 1, "second dropdown x should be 1")
assert(dlg.dropdowns.first_sub.y < dlg.dropdowns.second_sub.y,
    "first dropdown should be above second dropdown")
print("  Dropdowns stacked vertically at x=1: OK")

-- Labels directly above their dropdowns.
local first_lbl_y, second_lbl_y
for _, lbl in ipairs(dlg.labels) do
    if lbl.text == "First language:" then first_lbl_y = lbl.y end
    if lbl.text == "Second language (yellow)" then second_lbl_y = lbl.y end
end
assert(first_lbl_y == dlg.dropdowns.first_sub.y - 1,
    "First language label should be directly above first dropdown")
assert(second_lbl_y == dlg.dropdowns.second_sub.y - 1,
    "Second language label should be directly above second dropdown")
assert(dlg.dropdowns.first_sub.y < second_lbl_y,
    "second label should come after first dropdown")
print("  Labels above their dropdowns: OK")

-- Note label present.
local has_note = false
for _, lbl in ipairs(dlg.labels) do
    if lbl.text == "(note: the original files will not be harmed!)" then
        has_note = true
    end
end
assert(has_note, "Note label should exist")
print("  Note label present: OK")

H.cleanup()

print("\nALL DROPDOWN TESTS PASSED")
