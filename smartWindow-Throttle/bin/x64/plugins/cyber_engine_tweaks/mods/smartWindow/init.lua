-------------------------------------------------------------------------------------------------------------------------------
-- This mod was created by keanuWheeze from CP2077 Modding Tools Discord.
--
-- You are free to use this mod as long as you follow the following license guidelines:
--    * It may not be uploaded to any other site without my express permission.
--    * Using any code contained herein in another mod requires credits / asking me.
--    * You may not fork this code and make your own competing version of this mod available for download without my permission.
-------------------------------------------------------------------------------------------------------------------------------

local GameUI = require("modules/external/GameUI")
local Cron = require("modules/external/Cron")

mod = {
    runtimeData = {
        inMenu = false,
        inGame = false
    },
    logic = require("modules/logic")
}

function mod:new()
    registerForEvent("onInit", function()
        Observe('RadialWheelController', 'OnIsInMenuChanged', function(_, isInMenu) -- Setup observer and GameUI to detect inGame / inMenu
            self.runtimeData.inMenu = isInMenu
        end)

        GameUI.OnSessionStart(function()
            self.runtimeData.inGame = true
        end)

        GameUI.OnSessionEnd(function()
            self.runtimeData.inGame = false
        end)

        self.logic.init()
        self.runtimeData.inGame = not GameUI.IsDetached() -- Required to check if ingame after reloading all mods
    end)

    registerForEvent("onUpdate", function(dt)
        if not self.runtimeData.inMenu and self.runtimeData.inGame then
            Cron.Update(dt)
        end

        -- stupid unitialize controller observer doesnt work anymore
        -- [CET-Cleans] check twice a second and reuse one entEntityID per window instead of
        -- creating a new one for every window every frame (~13 objects/s per window held until Lua GC)
        self.sepTimer = (self.sepTimer or 0) + dt
        if self.sepTimer < 0.5 then return end
        self.sepTimer = 0
        self.sepIds = self.sepIds or {}
        for key, value in pairs(self.logic.controllers) do
            local id = self.sepIds[key]
            if not id then
                id = entEntityID.new({hash = key})
                self.sepIds[key] = id
            end
            if not Game.FindEntityByID(id) then
                value:uninit()
                self.logic.controllers[key] = nil
                self.sepIds[key] = nil
            end
        end
    end)

    return self
end

return mod:new()