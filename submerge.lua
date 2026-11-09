--[[
  Name:  SubMerge
  Description: Extension to merge 2 subtitle languages with each-other.
  Author: Doineann
  Version: 1.0
  License: GPL
--]]

function descriptor()
    return {
        title = "SubMerge",
        version = "1.0",
        author = "Doineann",
        shortdesc = "SubMerge",
        description = "Extension to merge 2 subtitle languages with each-other.",
        capabilities = { "dialog" }
    }
end

function activate()
    local dlg = vlc.dialog("SubMerge")
    if dlg then
        dlg:add_label("Hello, World!", 1, 1, 1, 1)
    end
end

function deactivate()
end

function close()
end
