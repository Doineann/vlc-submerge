-- test_dropdowns.lua
-- Tests: dropdown population, ordering, English first in first dropdown,
--        stacked layout (label, dropdown, label, dropdown), reverse order in second dropdown

vlc = {}

local widget_mt = {}
widget_mt.__index = {
    add_value = function(self, text, id) table.insert(self.values, text) end,
    get_value = function(self) return self.selected end,
    set_text = function(self, text) self.text = text end,
    set_checked = function(self, bool) end,
    delete = function(self) end
}

local dialog_mt = {}
dialog_mt.__index = {
    add_label = function(self, text, x, y, w, h)
        table.insert(self.labels, {text=text,x=x,y=y,w=w,h=h})
        return { set_text = function(s, t) self.labels[#self.labels].text = t end }
    end,
    add_button = function(self, text, func, x, y, w, h)
        table.insert(self.buttons, {text=text, fn=func})
    end,
    add_dropdown = function(self, name, x, y, w, h)
        local widget = { name = name, values = {}, selected = nil, x = x, y = y, w = w, h = h }
        setmetatable(widget, widget_mt)
        self.dropdowns[name] = widget
        return widget
    end,
    add_text_input = function(self, text) end,
    add_check_box = function(self, text, checked) end,
    add_image = function(self, filename) end,
    del_widget = function(self, widget) end,
    get_value = function(self, name)
        local widget = self.dropdowns[name]
        return widget and widget.selected or nil
    end,
    delete = function(self) end
}

function vlc.dialog(title)
    local d = { labels = {}, buttons = {}, dropdowns = {} }
    _G.test_dlg = d
    return setmetatable(d, dialog_mt)
end

-- Video playing with 3 subtitle files
vlc.input = { item = function() return { uri = function() return "file:///home/ray/Desktop/submerge/test.mkv" end } end }
vlc.player = { add_slave = function() return false end }

-- Clean up any leftover test files
local f = io.popen('ls /home/ray/Desktop/submerge/test.*.srt 2>/dev/null')
if f then
    for file in f:lines() do
        os.remove(file)
    end
    f:close()
end

-- Create test files
local f = io.open("/home/ray/Desktop/submerge/test.de.srt", "w"); f:write("1\n00:00:01,000 --> 00:00:05,000\nHallo\n\n"); f:close()
local f = io.open("/home/ray/Desktop/submerge/test.en.srt", "w"); f:write("1\n00:00:01,000 --> 00:00:05,000\nHello\n\n"); f:close()
local f = io.open("/home/ray/Desktop/submerge/test.nl.srt", "w"); f:write("1\n00:00:01,000 --> 00:00:05,000\nHallo\n\n"); f:close()

local chunk = assert(loadfile("submerge.lua"))
chunk()
activate()

local dlg = _G.test_dlg

-- Check first dropdown: English should be first (en before eng before de before nl)
local first = dlg.dropdowns.first_sub.values
assert(#first == 3, "first dropdown should have 3 values, got " .. #first)
assert(first[1] == "en", "first dropdown[1] should be 'en', got '" .. tostring(first[1]) .. "'")
assert(first[2] == "de", "first dropdown[2] should be 'de', got '" .. tostring(first[2]) .. "'")
assert(first[3] == "nl", "first dropdown[3] should be 'nl', got '" .. tostring(first[3]) .. "'")
print("  First dropdown order: " .. table.concat(first, ", ") .. " (English first: OK)")

-- Check second dropdown: reverse-sorted, first item different from first dropdown
local second = dlg.dropdowns.second_sub.values
assert(#second == 3, "second dropdown should have 3 values, got " .. #second)
assert(second[1] == "nl", "second dropdown[1] should be 'nl', got '" .. tostring(second[1]) .. "'")
assert(second[2] == "de", "second dropdown[2] should be 'de', got '" .. tostring(second[2]) .. "'")
assert(second[3] == "en", "second dropdown[3] should be 'en', got '" .. tostring(second[3]) .. "'")
print("  Second dropdown order: " .. table.concat(second, ", ") .. " (reverse of first: OK)")

-- Verify English is NOT first in second dropdown
assert(second[1] ~= "en" and second[1] ~= "eng", "English should not be first in second dropdown")
print("  English not first in second dropdown: OK")

-- Verify stacked layout: label, dropdown, label, dropdown (all x=1, w=4)
assert(dlg.dropdowns.first_sub.x == 1, "first dropdown x should be 1")
assert(dlg.dropdowns.second_sub.x == 1, "second dropdown x should be 1")
assert(dlg.dropdowns.first_sub.y < dlg.dropdowns.second_sub.y,
    "first dropdown should be above second dropdown")
print("  Dropdowns stacked vertically at x=1: OK")

-- Verify labels above their dropdowns
local first_lbl_y, second_lbl_y = nil, nil
for _, lbl in ipairs(dlg.labels) do
    if lbl.text == "First language:" then first_lbl_y = lbl.y end
    if lbl.text == "Second language (yellow)" then second_lbl_y = lbl.y end
end
assert(first_lbl_y and first_lbl_y == dlg.dropdowns.first_sub.y - 1,
    "First language label should be directly above first dropdown")
assert(second_lbl_y and second_lbl_y == dlg.dropdowns.second_sub.y - 1,
    "Second language label should be directly above second dropdown")
assert(dlg.dropdowns.first_sub.y < second_lbl_y,
    "second label should come after first dropdown")
print("  Labels above their dropdowns: OK")

-- Verify note label between dropdowns and buttons
local has_note = false
for _, lbl in ipairs(dlg.labels) do
    if lbl.text == "(note: the original files will not be harmed!)" then has_note = true end
end
assert(has_note, "Note label should exist")
print("  Note label present: OK")

-- Cleanup
os.remove("/home/ray/Desktop/submerge/test.de.srt")
os.remove("/home/ray/Desktop/submerge/test.en.srt")
os.remove("/home/ray/Desktop/submerge/test.nl.srt")

print("\nALL DROPDOWN TESTS PASSED")
