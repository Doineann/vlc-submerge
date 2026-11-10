-- test/helpers.lua
-- Shared VLC stubs and fixture utilities for the SubMerge test suite.
-- Load with: local H = dofile("test/helpers.lua")
-- Run from the repository root.

local H = {}

H.TMP = "test/tmp"

-----------------------------------------------------------------------------
-- VLC dialog / widget stubs
-----------------------------------------------------------------------------

local widget_mt = {}
widget_mt.__index = {
    add_value = function(self, text, id)
        self.values[#self.values + 1] = text
        self.entries[#self.entries + 1] = { text = text, id = id or 0 }
        -- VLC selects the first dropdown entry by default.
        if #self.entries == 1 then
            self.selected = text
        end
    end,
    -- Emulates VLC 3's Qt SyncSelection() + get_value():
    -- a selection is matched by id, and get_value() returns the first
    -- entry whose selected flag is set. Duplicate ids therefore mark every
    -- entry as selected and get_value() returns the first one.
    get_value = function(self)
        local chosen_id
        if self.selected ~= nil then
            for _, entry in ipairs(self.entries) do
                if entry.text == self.selected then
                    chosen_id = entry.id
                    break
                end
            end
        end

        for _, entry in ipairs(self.entries) do
            if chosen_id ~= nil and entry.id == chosen_id then
                return entry.id, entry.text
            end
        end
        return -1, nil
    end,
    set_text = function(self, text)
        self.text = text
    end,
    set_checked = function() end,
    delete = function() end,
}

local dialog_mt = {}
dialog_mt.__index = {
    add_label = function(self, text, x, y, w, h)
        local entry = { text = text, x = x, y = y, w = w, h = h }
        self.labels[#self.labels + 1] = entry
        return {
            set_text = function(_, value)
                entry.text = value
            end,
        }
    end,
    add_button = function(self, text, fn, x, y, w, h)
        self.buttons[#self.buttons + 1] = {
            text = text, fn = fn, x = x, y = y, w = w, h = h,
        }
    end,
    add_dropdown = function(self, name, x, y, w, h)
        local widget = {
            name = name, values = {}, entries = {}, selected = nil,
            x = x, y = y, w = w, h = h,
        }
        setmetatable(widget, widget_mt)
        self.dropdowns[name] = widget
        return widget
    end,
    add_text_input = function() end,
    add_check_box = function() end,
    add_image = function() end,
    del_widget = function() end,
    get_value = function(self, name)
        local widget = self.dropdowns[name]
        return widget and widget.selected or nil
    end,
    delete = function(self)
        self.deleted = true
    end,
}

-----------------------------------------------------------------------------
-- Setup
-----------------------------------------------------------------------------

-- Installs a fresh global `vlc` table.
--   opts.video        URI string of the current item, or nil for "no video".
--   opts.add_subtitle function used for vlc.input.add_subtitle, or false to
--                     omit it (forces the add_slave fallback).
--   opts.add_slave    function used for vlc.player.add_slave.
function H.setup(opts)
    opts = opts or {}
    vlc = {}
    _G.test_dlg = nil
    _G.test_deactivated = false

    function vlc.dialog()
        local d = { labels = {}, buttons = {}, dropdowns = {} }
        _G.test_dlg = d
        return setmetatable(d, dialog_mt)
    end

    -- Mirrors vlc.deactivate(): asks VLC to close the extension.
    function vlc.deactivate()
        _G.test_deactivated = true
    end

    local input = {}
    if opts.video then
        input.item = function()
            return { uri = function() return opts.video end }
        end
    else
        input.item = function() return nil end
    end

    if opts.add_subtitle == false then
        input.add_subtitle = nil
    else
        input.add_subtitle = opts.add_subtitle or function() return true end
    end

    vlc.input = input
    vlc.player = {
        add_slave = opts.add_slave or function() return false end,
    }
end

-- Loads submerge.lua, resetting its module state.
function H.load()
    local chunk = assert(loadfile("submerge.lua"))
    chunk()
end

-- The most recently created dialog.
function H.dlg()
    return _G.test_dlg
end

-- True if the extension asked VLC to close itself.
function H.deactivated()
    return _G.test_deactivated == true
end

-- Returns the first dialog button with the given label.
function H.button(dlg, text)
    for _, b in ipairs(dlg.buttons) do
        if b.text == text then return b end
    end
    return nil
end

-- Clicks the button with the given label. Returns ok, err.
function H.click(dlg, text)
    local b = H.button(dlg, text)
    if not b then return false, "button not found: " .. text end
    return pcall(b.fn)
end

-----------------------------------------------------------------------------
-- Fixtures
-----------------------------------------------------------------------------

-- Clears and recreates the temporary fixture directory.
function H.reset_tmp()
    os.execute("mkdir -p '" .. H.TMP .. "' && rm -f '" .. H.TMP .. "'/*.srt")
end

-- Removes the temporary fixture directory.
function H.cleanup()
    os.execute("rm -rf '" .. H.TMP .. "'")
end

-- Repository root (tests must be run from there).
function H.root()
    local pipe = assert(io.popen("pwd"))
    local dir = pipe:read("*l")
    pipe:close()
    return dir
end

-- file:// URI for the fake video used by the tests.
function H.video_uri()
    return "file://" .. H.root() .. "/" .. H.TMP .. "/test.mkv"
end

-- Absolute-ish path to a fixture file inside the temporary directory.
function H.srt(name)
    return H.TMP .. "/" .. name
end

function H.write(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

-- A single-cue SRT body.
function H.cue(start_time, end_time, text)
    return "1\n" .. start_time .. " --> " .. end_time .. "\n" .. text .. "\n\n"
end

return H
