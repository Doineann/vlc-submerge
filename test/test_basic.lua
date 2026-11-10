-- test_basic.lua
-- Tests: activation, dialog creation, shortdesc, version

vlc = {}

-- Stub dialog
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
        local widget = { name = name, values = {}, selected = nil }
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
    return setmetatable(d, dialog_mt)
end

-- No video playing
vlc.input = { item = function() return nil end }
vlc.player = { add_slave = function() return false end }

-- Load the extension
local chunk = assert(loadfile("submerge.lua"))
chunk()

-- Test descriptor
local desc = descriptor()
assert(desc.title == "SubMerge", "title should be SubMerge")
assert(desc.version == "1.3", "version should be 1.3")
assert(desc.shortdesc == "SubMerge", "shortdesc must be exactly 'SubMerge'")
assert(desc.author == "Doineann", "author should be Doineann")
assert(desc.license == "GPL", "license should be GPL")
assert(desc.capabilities and desc.capabilities[1] == "input-listener",
    "should declare input-listener capability")

print("  descriptor: OK")

-- Test activate (no video)
local ok, err = pcall(function() activate() end)
assert(ok, "activate() should not error without video: " .. tostring(err))
print("  activate() without video: OK")

-- Test deactivate
deactivate()
print("  deactivate(): OK")

-- Test input_changed
local ok2, err2 = pcall(function() input_changed() end)
assert(ok2, "input_changed() should not error: " .. tostring(err2))
print("  input_changed(): OK")

print("\nALL BASIC TESTS PASSED")
