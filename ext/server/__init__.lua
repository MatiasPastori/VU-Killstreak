local settings = require("settings.lua")
local outputs = 0
local debug = false
local str = ""
if debug then
    str = "configurationDevelopment.lua"
else
    str = "configuration.lua"
end

local conf = require(str)

local lastOut = 0
KillstreakServer = class("KillstreakServer")


function KillstreakServer:__init()
    print("Initializing server module")
    -- self.playerScores = {}
    self.playerKillstreakScore = {}
    self.playerKillstreaks = {}
    self.playerScoreDisabled = {}
    Events:Subscribe("Level:Loaded", self, self.OnLevelLoaded)
    Events:Subscribe("Level:Destroy", self, self.OnLevelDestroy)
    Events:Subscribe("Player:Left", self, self.OnPlayerLeft)
    NetEvents:Subscribe("Killstreak:newClient", self, self.sendConfToNewClient)
    NetEvents:Subscribe("Killstreak:notifyServerUsedSteps", self, self.usedSteps)
    NetEvents:Subscribe("Killstreak:updatePlayerKS", self, self.updatePlayerKS)

    Events:Subscribe(
        "Server:RoundOver",
        self,
        function()
            NetEvents:Broadcast("Killstreak:hideAll")
            -- for i, v in pairs(self.playerScores) do
            --     self.playerScores[i] = 0
            -- end
            for i, v in pairs(self.playerKillstreakScore) do
                self.playerKillstreakScore[i] = 0
                NetEvents:SendTo("Killstreak:ScoreUpdate", PlayerManager:GetPlayerById(i), tostring(0))
            end
        end
    )

    Events:Subscribe(
        "Server:RoundReset",
        self,
        function()
            NetEvents:Broadcast("Killstreak:hideAll")
            -- for i, v in pairs(self.playerScores) do
            --     self.playerScores[i] = 0
            -- end
            for i, v in pairs(self.playerKillstreakScore) do
                self.playerKillstreakScore[i] = 0
            end
            NetEvents:Broadcast("Killstreak:ScoreUpdate", tostring(0))
        end
    )
    Events:Subscribe(
        "Player:Authenticated",
        self,
        function(player)
            if self.playerKillstreakScore[player.id] ~= nil then
                NetEvents:SendTo(
                    "Killstreak:ScoreUpdate",
                    player,
                    tostring(self.playerKillstreakScore[player.id])
                )
            end
        end
    )

    Events:Subscribe("Player:Killed", self, self.playerKilled)
    Events:Subscribe("Player:ManDownRevived", self, self.playerRevived)
    if settings.ignoreScoreInVehicle then
        Events:Subscribe("Vehicle:Enter", self, self.disableScore)
        Events:Subscribe("Vehicle:Exit", self, self.enableScore)
    end
end

function KillstreakServer:disableScore(vehicle, player)
    self.playerScoreDisabled[player.id] = true
end

function KillstreakServer:enableScore(vehicle, player)
    self.playerScoreDisabled[player.id] = false
end

--- This handler will manage the logic for when a player gets killed:
--- Three cases here: 1. The player killed an enemy, 2. The player killed a teammate, 3. The player killed himself
---@param player Player
---@param inflictor Player | nil
function KillstreakServer:playerKilled(player, inflictor)
    if settings.resetOnDeath then
        self:resetScore(player)
    end

    if inflictor then
        if inflictor.teamId == player.teamId and self.playerKillstreakScore[inflictor.id] then
            -- This is to avoid negative values.
            self.playerKillstreakScore[inflictor.id] = math.max(self.playerKillstreakScore[inflictor.id] - 200, 0)
            NetEvents:SendTo("Killstreak:ScoreUpdate", inflictor, tostring(self.playerKillstreakScore[inflictor.id]))
        end
    end

    NetEvents:SendTo("Killstreak:DisableInteraction", player)
end

function KillstreakServer:playerRevived(player)
    NetEvents:SendTo("Killstreak:EnableInteraction", player)
end

function KillstreakServer:resetScore(player, punisher, position, weapon, isRoadKill, isHeadShot, wasVictimInREviveState)
    if self.playerKillstreakScore[player.id] ~= 0 then
        self.playerKillstreakScore[player.id] = 0
        NetEvents:SendTo("Killstreak:ScoreUpdate", player, tostring(self.playerKillstreakScore[player.id]))
    end
end

function KillstreakServer:__gc()
    Events:Unsubscribe("Player:Score")
    Events:Unsubscribe("Level:Loaded")
    Events:Unsubscribe("Level:Destroy")
    Events:Unsubscribe("Player:Killed")
    Events:Unsubscribe("Vehicle:Exit")
    Events:Unsubscribe("Vehicle:Enter")
    NetEvents:Unsubscribe()
end

function KillstreakServer:OnLevelLoaded()
    -- Events:Subscribe("Player:Update", self, self.OnPlayerUpdate)
    Events:Subscribe("Player:Score", self, self.OnPlayerScore)
end

function KillstreakServer:sendConfToNewClient(player)
    if self.playerKillstreaks[player.id] == nil then
        self.playerKillstreaks[player.id] = {}
    end
    if self.playerScoreDisabled[player.id] == nil then
        self.playerScoreDisabled[player.id] = false
    end
    if self.playerKillstreakScore[player.id] ~= nil and self.playerKillstreakScore[player.id] ~= 0 then
        NetEvents:SendTo("Killstreak:ScoreUpdate", player, tostring(self.playerKillstreakScore[player.id]))
    end
    NetEvents:SendTo("Killstreak:Client:getConf", player, json.encode(conf))
end

function KillstreakServer:updatePlayerKS(player, ks)
    self.playerKillstreaks[player.id] = ks
end

function KillstreakServer:OnLevelDestroy()
    -- Events:Unsubscribe("Player:Update")
    Events:Unsubscribe("Player:Score")
    self.playerKillstreakScore = {}
    -- self.playerScores = {}
end

function KillstreakServer:OnPlayerLeft(player)
    self.playerKillstreaks[player.id] = nil
    self.playerScoreDisabled[player.id] = false
    -- self.playerScores[player.id] = nil
    self.playerKillstreakScore[player.id] = nil
    return
end

function KillstreakServer:usedSteps(playerObj, usedStep)
    self.playerKillstreakScore[playerObj.id] =
        self.playerKillstreakScore[playerObj.id] - self.playerKillstreaks[playerObj.id][usedStep][3]

    NetEvents:SendTo("Killstreak:ScoreUpdate", playerObj, tostring(self.playerKillstreakScore[playerObj.id]))
end

-- function KillstreakServer:OnPlayerUpdate(player, deltaTime)
--     if not player.hasSoldier then
--         return
--     end

--     if self.playerScores[player.id] ~= nil and self.playerScoreDisabled[player.id] then
--         if player.score > self.playerScores[player.id] then
--             self.playerScores[player.id] = player.score
--         end
--         return
--     end
--     modified = false

--     if self.playerScores[player.id] == nil then
--         self.playerScores[player.id] = player.score
--         self.playerKillstreakScore[player.id] = player.score
--         modified = true
--     end

--     if player.score > self.playerScores[player.id] and not modified then
--         self.playerKillstreakScore[player.id] =
--             self.playerKillstreakScore[player.id] + (player.score - self.playerScores[player.id])
--         self.playerScores[player.id] = player.score
--         modified = true
--     end
--     if modified and self.playerKillstreakScore[player.id] ~= nil then
--         NetEvents:SendTo("Killstreak:ScoreUpdate", player, tostring(self.playerKillstreakScore[player.id]))
--     end
-- end

---Its more efficient to calculate and save the score of a player when it actually gains scores from a given action and not for each second the game passes
---@param player Player
---@param scoringTypeData DataContainer
---@param score integer
function KillstreakServer:OnPlayerScore(player, scoringTypeData, actionScore)
    if not player.hasSoldier then
        return
    end
    if self.playerKillstreakScore[player.id] then
        self.playerKillstreakScore[player.id] = self.playerKillstreakScore[player.id] + actionScore
    else
        self.playerKillstreakScore[player.id] = actionScore
    end

    NetEvents:SendTo("Killstreak:ScoreUpdate", player, tostring(self.playerKillstreakScore[player.id]))
end

if debug then
    Events:Subscribe(
        "Player:Chat",
        function(player, recipientMask, message)
            if message == "!timertest" then
                NetEvents:SendTo("Killstreak:newTimer", player, json.encode({ duration = 40, text = "Test Timer" }))
            end
            if message == "!mestest" then
                NetEvents:SendTo(
                    "Killstreak:showNotification",
                    player,
                    json.encode({ message = "Test Message", title = "Test Title" })
                )
            end
        end
    )
end

KillstreakServer = KillstreakServer()

return KillstreakServer
