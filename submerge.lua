--[[
  Name:        SubMerge
  Description: Merge two external language-specific SRT subtitle files.
  Author:      Doineann
  Version:     1.2
  License:     GPL

  VLC 3.x Lua extension.

  Scans external SRT files associated with the currently playing local video.
  The two selected files are merged chronologically. The second language
  is wrapped in an SRT-compatible yellow font tag.

  No directories are created. Source subtitle files are never modified.
--]]



function descriptor()
return {
    title = "SubMerge",
    version = "1.2",
    author = "Doineann",
    shortdesc = "SubMerge",
    description = "Scan, merge and load language-tagged external SRT files.",
    capabilities = { "input-listener" }
}
end

function activate()
refresh_dialog()
end

function deactivate()
if dlg then
    dlg:delete()
    dlg = nil
    end

    status_label = nil
    end

    function close()
    vlc.deactivate()
    end

local dlg = nil
local subtitle_files = {}
local video_path = nil
local video_dir = nil
local video_stem = nil
local status_label = nil

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

local function path_join(a, b)
    local sep = is_windows() and "\\" or "/"
    if a:sub(-1) == "/" or a:sub(-1) == "\\" then
        return a .. b
    end
    return a .. sep .. b
end

local function basename(path)
    return path:match("([^/\\]+)$") or path
end

local function dirname(path)
    return path:match("^(.*)[/\\][^/\\]+$") or "."
end

local function strip_extension(name)
    return name:gsub("%.[^%.]+$", "")
end

local function shell_quote(s)
    if is_windows() then
        return '"' .. s:gsub('"', '\\"') .. '"'
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function uri_decode(s)
    s = s:gsub("^file://", "")
    s = s:gsub("^localhost", "")
    s = s:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)

    if is_windows() and s:match("^/[A-Za-z]:") then
        s = s:sub(2)
    end
    return s
end

local function uri_encode_path(path)
    local p = path:gsub("\\", "/")
    p = p:gsub("([^%w%-%._~/:%])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)

    if p:match("^[A-Za-z]:/") then
        return "file:///" .. p
    end
    if p:sub(1, 1) == "/" then
        return "file://" .. p
    end
    return "file://" .. p
end

local function get_current_video()
    local item = vlc.input.item()
    if not item then return false end

    local uri = item:uri()
    if not uri or not uri:match("^file://") then
        return false
    end

    video_path = uri_decode(uri)
    video_dir = dirname(video_path)
    video_stem = strip_extension(basename(video_path))
    return true
end

local function list_srt_files(dir)
    local results = {}
    local command

    if is_windows() then
        command = 'dir /b /a-d ' .. shell_quote(path_join(dir, "*.srt")) ..
                  ' 2>NUL'
    else
        command = 'find ' .. shell_quote(dir) ..
                  ' -maxdepth 1 -type f -iname "*.srt" -print 2>/dev/null'
    end

    local pipe = io.popen(command)
    if not pipe then return results end

    for line in pipe:lines() do
        line = line:gsub("[\r\n]+$", "")
        if line ~= "" then
            if is_windows() and not line:match("^[/\\]?[%a]:[/\\]") then
                line = path_join(dir, line)
            elseif not is_windows() and line:sub(1, 1) ~= "/" then
                line = path_join(dir, line)
            end
            results[#results + 1] = line
        end
    end

    pipe:close()
    return results
end

local function directory_exists(path)
    local command

    if is_windows() then
        command = 'if exist ' .. shell_quote(path_join(path, ".")) ..
                  ' (exit 0) else (exit 1)'
    else
        command = 'test -d ' .. shell_quote(path)
    end

    local ok = os.execute(command)
    return ok == true or ok == 0
end

local function get_scan_directories()
    local dirs = { video_dir }

    local names = {
        "Subs", "subs", "SUBS",
        "Subtitles", "subtitles", "SUBTITLES",
        "Subtitle", "subtitle",
        "Sub", "sub"
    }

    local seen = { [video_dir:lower()] = true }

    for _, name in ipairs(names) do
        local dir = path_join(video_dir, name)

        if not seen[dir:lower()] and directory_exists(dir) then
            dirs[#dirs + 1] = dir
            seen[dir:lower()] = true
        end
    end

    return dirs
end

local function escape_pattern(s)
    return (s:gsub("([^%w])", "%%%1"))
end

local function get_language_tag(path)
    local filename = basename(path)
    local stem = escape_pattern(video_stem)

    local tail = filename:match("^" .. stem .. "%.(.+)%.srt$")
    if not tail then return nil end

    local tag = tail:match("^([%a][%a][%a]?)")
    if not tag then return nil end

    local rest = tail:sub(#tag + 1)
    local region = rest:match("^[-_]([%a][%a])")

    if region then
        tag = tag .. "-" .. region
        rest = rest:sub(4)
    elseif rest ~= "" and not rest:match("^[%.%-_]") then
        return nil
    end

    if rest ~= "" and not rest:match("^[%.%-_][%w%.%-_]*$") then
        return nil
    end

    return tag:lower()
end

local function scan_subtitles()
    subtitle_files = {}
    local seen = {}

    for _, dir in ipairs(get_scan_directories()) do
        for _, path in ipairs(list_srt_files(dir)) do
            local key = path:lower()

            if not seen[key] then
                seen[key] = true

                local tag = get_language_tag(path)

                if tag then
                    subtitle_files[#subtitle_files + 1] = {
                        path = path,
                        tag = tag,
                        label = tag .. "  —  " .. basename(path)
                    }
                end
            end
        end
    end

    table.sort(subtitle_files, function(a, b)
        if a.tag == b.tag then
            return a.path:lower() < b.path:lower()
        end
        return a.tag < b.tag
    end)
end

local function parse_time(value)
    local h, m, s, ms = value:match(
        "^(%d%d):(%d%d):(%d%d),(%d%d%d)$"
    )

    if not h then return nil end

    return (((tonumber(h) * 60 + tonumber(m)) * 60) +
            tonumber(s)) * 1000 + tonumber(ms)
end

local function format_time(ms)
    local h = math.floor(ms / 3600000)
    ms = ms - h * 3600000

    local m = math.floor(ms / 60000)
    ms = ms - m * 60000

    local s = math.floor(ms / 1000)
    local milli = ms - s * 1000

    return string.format("%02d:%02d:%02d,%03d", h, m, s, milli)
end

local function read_srt(path, color_yellow)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end

    local content = f:read("*a")
    f:close()

    content = content:gsub("^\239\187\191", "")
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
    content = content .. "\n\n"

    local cues = {}

    for block in content:gmatch("(.-)\n%s*\n") do
        local lines = {}

        for line in (block .. "\n"):gmatch("(.-)\n") do
            if line ~= "" then
                lines[#lines + 1] = line
            end
        end

        local timing_line

        for i, line in ipairs(lines) do
            if line:find("%d%d:%d%d:%d%d,%d%d%d%s*%-%->") then
                timing_line = i
                break
            end
        end

        if timing_line then
            local start_s, end_s = lines[timing_line]:match(
                "(%d%d:%d%d:%d%d,%d%d%d)%s*%-%->%s*(%d%d:%d%d:%d%d,%d%d%d)"
            )

            local start_ms = start_s and parse_time(start_s)
            local end_ms = end_s and parse_time(end_s)

            if start_ms and end_ms and end_ms >= start_ms then
                local text_lines = {}

                for i = timing_line + 1, #lines do
                    text_lines[#text_lines + 1] = lines[i]
                end

                if #text_lines > 0 then
                    local cue_text = table.concat(text_lines, "\n")

                    if color_yellow then
                        cue_text = '<font color="#FFFF00">' ..
                                   cue_text .. '</font>'
                    end

                    cues[#cues + 1] = {
                        start_ms = start_ms,
                        end_ms = end_ms,
                        text = cue_text
                    }
                end
            end
        end
    end

    return cues
end

local function merge_subtitles(first, second, output_path)
    local first_cues, err = read_srt(first.path, false)
    if not first_cues then return false, err end

    local second_cues, err2 = read_srt(second.path, true)
    if not second_cues then return false, err2 end

    local cues = {}

    for _, cue in ipairs(first_cues) do
        cues[#cues + 1] = cue
    end

    for _, cue in ipairs(second_cues) do
        cues[#cues + 1] = cue
    end

    table.sort(cues, function(a, b)
        if a.start_ms == b.start_ms then
            return a.end_ms < b.end_ms
        end
        return a.start_ms < b.start_ms
    end)

    local f, write_err = io.open(output_path, "wb")
    if not f then return false, write_err end

    for i, cue in ipairs(cues) do
        f:write(tostring(i), "\n")
        f:write(format_time(cue.start_ms), " --> ",
                format_time(cue.end_ms), "\n")
        f:write(cue.text, "\n\n")
    end

    f:close()
    return true
end

local function set_status(message)
    if status_label then
        status_label:set_text(message)
    elseif dlg then
        status_label = dlg:add_label(message, 1, 100, 3, 1)
    end
end

local function merge_selected()
    if not get_current_video() then
        set_status("Error: no local video is currently playing.")
        return
    end

    local first_index = tonumber(dlg:get_value("first_sub"))
    local second_index = tonumber(dlg:get_value("second_sub"))

    if not first_index or not second_index or
       not subtitle_files[first_index] or
       not subtitle_files[second_index] then
        set_status("Select two subtitle files.")
        return
    end

    if first_index == second_index then
        set_status("Select two different subtitle files.")
        return
    end

    local first = subtitle_files[first_index]
    local second = subtitle_files[second_index]

    if first.tag == second.tag then
        set_status("Both files have the same language tag.")
        return
    end

    local output_name = video_stem .. "." ..
                        first.tag .. "-" .. second.tag .. ".srt"

    local output_path = path_join(video_dir, output_name)

    local ok, err = merge_subtitles(first, second, output_path)

    if not ok then
        set_status("Merge failed: " .. tostring(err))
        return
    end

    local loaded = false

    if vlc.player and vlc.player.add_slave then
        loaded = vlc.player.add_slave(
            "subtitle", uri_encode_path(output_path), true
        )
    end

    if loaded then
        set_status("Merged and loaded: " .. output_name)
    else
        set_status("Created " .. output_name ..
                   " but VLC could not load it automatically.")
    end
end

local function refresh_dialog()
    if dlg then
        dlg:delete()
    end

    dlg = vlc.dialog("SubMerge")
    status_label = nil

    if not get_current_video() then
        dlg:add_label("Play a local video file, then refresh.", 1, 1, 3, 1)
        dlg:add_button("Refresh", refresh_dialog, 1, 2, 1, 1)
        return
    end

    scan_subtitles()

    dlg:add_label("Video: " .. basename(video_path), 1, 1, 3, 1)
    dlg:add_label("External subtitle files found:", 1, 2, 3, 1)

    if #subtitle_files == 0 then
        dlg:add_label("No matching SRT files found.", 1, 3, 3, 1)
        dlg:add_label("Expected: video-name.<language>.srt",
                      1, 4, 3, 1)
        dlg:add_button("Refresh", refresh_dialog, 1, 5, 1, 1)
        return
    end

    local row = 3

    for _, sub in ipairs(subtitle_files) do
        dlg:add_label("[FILE] " .. sub.label, 1, row, 3, 1)
        row = row + 1
    end

    row = row + 1

    dlg:add_label("First language:", 1, row, 1, 1)
    dlg:add_label("Second language (yellow):", 2, row, 2, 1)

    row = row + 1

    dlg:add_dropdown("first_sub", 1, row, 1, 1)
    dlg:add_dropdown("second_sub", 2, row, 2, 1)

    for _, sub in ipairs(subtitle_files) do
        dlg:add_value("first_sub", sub.label)
        dlg:add_value("second_sub", sub.label)
    end

    row = row + 1

    dlg:add_button("Merge and load", merge_selected, 1, row, 2, 1)
    dlg:add_button("Refresh", refresh_dialog, 3, row, 1, 1)

    row = row + 1

    status_label = dlg:add_label(
        "Select two files. Original files will not be modified.",
        1, row, 3, 1
    )
end