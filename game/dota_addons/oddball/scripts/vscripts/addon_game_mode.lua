-- Generated from template

if GameMode == nil then
    _G.GameMode = class({})
    _G.GameMode.__index = _G.GameMode
end

require('item_functions')
require('libraries/timers')

function Precache( context )
        PrecacheResource("soundfile", "soundevents/oddball_sounds.vsndevts", context)
        PrecacheResource( "model", "*.vmdl", context )
        PrecacheResource( "soundfile", "*.vsndevts", context )
        PrecacheResource( "particle", "*.vpcf", context )
        PrecacheResource( "particle_folder", "particles/folder", context )
        PrecacheItemByNameSync("item_oddball", context)
end

-- Create the game mode when we activate
function Activate()
    GameRules.AddonTemplate = GameMode()
    GameRules.AddonTemplate:InitGameMode()
end

function GameMode:InitGameMode()
    -- Points
    GameMode.Points = {}
    GameMode.Points[2] = 0
    GameMode.Points[3] = 0
    GameMode.POINTS_TO_WIN = 250
    GameMode.PointBonus = {}
    GameMode.PointBonus[2] = 0
    GameMode.PointBonus[3] = 0

    -- Buff pad settings
    GameMode.buffPadCooldown = 30

    -- Ball Settings
    GameMode.ballSpawnLocation = Entities:FindByName(nil, 'ball_spawner'):GetAbsOrigin()
    GameMode.ballInitialPickup = false
    GameMode.ballResapwnTimer = 0
    GameMode.ballResapwnTimerMax = 10

    -- Keep track of the points so that we can respawn the ball when it hasn't been picked up
    GameMode.ballPointTrack = {}
    GameMode.ballPointTrack[2] = 0
    GameMode.ballPointTrack[3] = 0

    -- Set Rosh spawn times
    GameMode.RoshSpawnTresh1 = GameMode.POINTS_TO_WIN * 0.4
    GameMode.RoshSpawnTresh2 = GameMode.POINTS_TO_WIN * 0.6

    -- Save Game mode to a global variable for functions that aren't in this file to reference
    GameRules:GetGameModeEntity().GameMode = self

    GameMode:SetGlobalAbilityUnit()

    -- Create Teams
    GameMode:GatherAndRegisterValidTeams();

    -- Global Think
    GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )

    -- Listeners
    ListenToGameEvent("npc_spawned", OnNPCSpawned, nil)
    ListenToGameEvent("last_hit", Dynamic_Wrap(GameMode, 'onLastHit'), self)
    ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(GameMode, 'StateChanged'), nil)
    ListenToGameEvent('dota_item_picked_up', Dynamic_Wrap(GameMode, 'BallPickedUp'), self)

    Convars:RegisterCommand( "ob_summon_rosh", function(...) self:SpawnRoshan() end, "Summon Roshan", FCVAR_CHEAT )
    Convars:RegisterCommand( "gimme_gimme", function(...) self:AllTheGolds() end, "All the moneyz", FCVAR_CHEAT )
    Convars:RegisterCommand( "spawn_ball", function(...) self:SpawnBall(GameMode.ballSpawnLocation) end, "Spawn the ball yo", FCVAR_CHEAT )
end

function GameMode:StateChanged()
    local game = GameRules:GetGameModeEntity().GameMode
    local state = GameRules:State_Get()

    if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
        EmitGlobalSound('Oddball.oddball') 
    elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
        -- Help text event
        Timers:CreateTimer({
            endTime = 5,
            callback = function()
                CustomGameEventManager:Send_ServerToAllClients('prepare_pre_game', nil)
            end
        })

        -- Add vision of the ball so the particles render
        AddFOWViewer(2, game.ballSpawnLocation, 150, 30, false)
        AddFOWViewer(3, game.ballSpawnLocation, 150, 30, false)

        game:SpawnBall(game.ballSpawnLocation)
    elseif state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        EmitGlobalSound('Oddball.playball')
        game:RemoveStunModifier()
    end
end

-- Evaluate the state of the game
function GameMode:OnThink()

    if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
    elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        GameMode:ExperiencePerTick()
        GameMode:SpawnRoshan()
    elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
        return nil
    end

    return 1
end

function GameMode:SpawnRoshan()
    if ThreshHit(self.RoshSpawnTresh1, self.Points[2], self.Points[3]) or ThreshHit(self.RoshSpawnTresh2, self.Points[2], self.Points[3]) and RoshNotSpawned() then
        local spawnPoint = Entities:FindByName(nil, 'roshan_spawner')
        local roshan = CreateUnitByName('npc_ob_roshan', spawnPoint:GetAbsOrigin(), true, nil, nil, 0)

        local ability = self.GlobalAbilityUnit:FindAbilityByName('ob_roshan_mods')
        ability:ApplyDataDrivenModifier(self.GlobalAbilityUnit, roshan, "modifier_on_roshan_death", nil)
        
        CustomGameEventManager:Send_ServerToTeam(2, "roshan_spawned", { spawn_location = spawnPoint:GetAbsOrigin(), hasBall = (2 == self.teamWithBall) } )
        CustomGameEventManager:Send_ServerToTeam(3, "roshan_spawned", { spawn_location = spawnPoint:GetAbsOrigin(), hasBall = (3 == self.teamWithBall) } )
    end
end

function ThreshHit(thresh, team1Points, team2Points)
    return math.floor(thresh) == team1Points or math.floor(thresh) == team2Points
end

function RoshNotSpawned()
    local units = FindUnitsInRadius(
        DOTA_TEAM_NEUTRALS, 
        Vector(0, 0, 0), 
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _,unit in pairs(units) do
        if unit:GetUnitName() == 'npc_ob_roshan' then
            return false
        end
    end

    return true
end

function GameMode:AllTheGolds()
    local heroes = HeroList:GetAllHeroes()

    for k,v in pairs(heroes) do
        v:ModifyGold(50000, true, 0)
    end
end

-- Level up all heroes to lvl 5 at the start of the game
function GameMode:LevelUpHero(hero)
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
        hero:AddExperience( 1400, 0, false, false )
    end
end

-- Give all heroes experience ever tick
function GameMode:ExperiencePerTick()
    local heroes = HeroList:GetAllHeroes()

    for i,hero in pairs(heroes) do
        hero:AddExperience( 20, 0, false, false )
    end
end

-- Get the ball when it is dropped
function GameMode:getDroppedBall()
    local int = GameRules:NumDroppedItems()

    for i = 0, int - 1 do
        local drop = GameRules:GetDroppedItem(i)
        if drop:GetModelName() == "models/oddball/oddball.vmdl" then
            return drop
        end
    end
end

-- Spawn the ball
function GameMode:SpawnBall(location)
    -- Add vision of the ball so the particles render
    AddFOWViewer(2, location, 150, 3, false)
    AddFOWViewer(3, location, 150, 3, false)

    local game = GameRules:GetGameModeEntity().GameMode
    local ball = CreateItem( "item_oddball", nil, nil )
    -- Create the actual item on the ground
    local drop = CreateItemOnPositionSync(location, ball)

    ball:SetContextThink( "RespawnBallCheck", function() return game:RespawnBallCheck( ball ) end, 1 )
    -- ball:SetContextThink( "GiveVisionOfBall", function() return game:GiveVisionOfBall(drop) end, 0.25)
end
    
-- Handles the logic of respawning the ball when it hasn't been picked up for 10 seconds
function GameMode:RespawnBallCheck(ball)
    local game = GameRules:GetGameModeEntity().GameMode
    game.teamWithBall = 0
    game.itemBall = ball;

    game.ballPointTrack[2] = game.ballPointTrack[2] + 1
    game.ballPointTrack[3] = game.ballPointTrack[3] + 1

    -- If the points haven't incremented
    if game.Points[2] ~= game.ballPointTrack[2] and game.Points[3] ~= game.ballPointTrack[3] and game.ballInitialPickup then
        game.ballResapwnTimer = game.ballResapwnTimer + 1
    end

    -- If the ball hasn't been picked up in 10 seconds after initially being picked up
    if game.ballResapwnTimer == game.ballResapwnTimerMax then
        game.ballInitialPickup = false
        game.ballResapwnTimer = 0

        -- Delete the ball and re spawn it
        UTIL_Remove(ball)
        UTIL_Remove(game.getDroppedBall())
        GameMode:SpawnBall(game.ballSpawnLocation)
        EmitGlobalSound('Oddball.ballReset')
    end

    if game.getDroppedBall() ~= nil then
        local drop = game.getDroppedBall():GetAbsOrigin()
        GameMode:ShowBallOnMinimap(drop.x, drop.y)
    end

    return 1
end

function GameMode:ShowBallOnMinimap(x, y)
    MinimapEvent( 2, self.GlobalAbilityUnit, x, y, DOTA_MINIMAP_EVENT_TEAMMATE_TELEPORTING, 1 )
    MinimapEvent( 3, self.GlobalAbilityUnit, x, y, DOTA_MINIMAP_EVENT_TEAMMATE_TELEPORTING, 1 )
end

-- Runs every time an NPC is spawned
function OnNPCSpawned(event)
    local npc = EntIndexToHScript(event.entindex)

    StunAllPlayers(npc)
    GameMode:GiveNeutralsBuffAbility(npc)
    GameMode:RandomRespawnPoint(npc)
    GameMode:LevelUpHero(npc)
end

-- Stuns all players during the pre game
function StunAllPlayers(npc)
    if npc:IsRealHero() and GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
        npc:AddNewModifier(nil, nil, "modifier_stunned", nil)
    end
end

-- Removes stun from all players when the game is in progress
function GameMode:RemoveStunModifier()
    local heroes = HeroList:GetAllHeroes()
    for i,hero in pairs(heroes) do
        hero:RemoveModifierByName("modifier_stunned")
    end
end

-- Gets a respawn point and moves the hero to that location when they spawn
function GameMode:RandomRespawnPoint(npc)
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_PRE_GAME then 
        local vector = getRandomRespawnVector()
        if npc:IsHero() then
            npc:SetOrigin(vector)
        end
    end
end

-- Returns on of the respawn points on the map
function getRandomRespawnVector()
    local points = Entities:FindAllByName('ob_respawn_point')
    local i = RandomInt( 1, 16 )
    return points[i]:GetAbsOrigin()
end

-- Gets the global ability unit and sets it for use throughout the map
function GameMode:SetGlobalAbilityUnit()
    local units = FindUnitsInRadius(
        DOTA_TEAM_NEUTRALS, 
        Vector(0, 0, 0), 
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _,unit in pairs(units) do
        if unit:GetUnitName() == 'ob_global_ability_unit' then
            self.GlobalAbilityUnit = unit
        end
    end
end

-- Gives the specified neutral creeps an on death modifier so they can give buffs when killed
function GameMode:GiveNeutralsBuffAbility(npc)
    if npc:GetName() == 'npc_dota_creep_neutral' then
        -- Get the on death give buff modifier from our global ability unit
        local ability = self.GlobalAbilityUnit:FindAbilityByName('npc_neutral_jungle_buff')

        -- Neutrals to give the on death buff to
        -- Npc name | use this npc?
        local npcs = {
            npc_dota_neutral_alpha_wolf = true,
            npc_dota_neutral_enraged_wildkin = true,
            npc_dota_neutral_polar_furbolg_ursa_warrior = true,
            npc_dota_neutral_dark_troll_warlord = true,
            npc_dota_neutral_satyr_hellcaller = true,
            npc_dota_neutral_centaur_khan = true
        }
    
        for name,use in pairs(npcs) do
            if npc:GetUnitName() == name then
                ability:ApplyDataDrivenModifier(self.GlobalAbilityUnit, npc, "modifier_give_buff_on_death", nil)
            end
        end
    end
end

-- Triggers when a player gets a last hit
function GameMode:onLastHit(player, ent, fb, hero, tower)
    local game = GameRules:GetGameModeEntity().GameMode
    BonusPointsOnKill(game, player, hero)
end

function BonusPointsOnKill(game, player, hero)
    if player.team == game.teamWithBall and hero then
        game.PointBonus[player.team] = game.PointBonus[player.team] + 1
    end
end

-- Give constant vision of the ball
function GameMode:GiveVisionOfBall(drop)
    local ball = Entities:FindByName(nil, 'item_oddball')
    local origin = ball:GetAbsOrigin()

    if origin == Vector(0, 0, 0) then
        origin = drop:GetAbsOrigin()
    end

    if ball then
        AddFOWViewer(2, origin, 150, 0.5, false)
        AddFOWViewer(3, origin, 150, 0.5, false)
    end

    return 0.25
end

-- When the ball is picked up
function GameMode:BallPickedUp(data)
    if data.itemname == 'item_oddball' then
        local hero = EntIndexToHScript(data.HeroEntityIndex)
        EmitSoundOnClient('Oddball.youHaveBall', hero:GetPlayerOwner())
    end
end

function GameMode:GatherAndRegisterValidTeams()
--  print( "GatherValidTeams:" )

    local foundTeams = {}
    for _, playerStart in pairs( Entities:FindAllByClassname( "info_player_start_dota" ) ) do
        foundTeams[  playerStart:GetTeam() ] = true
    end

    local numTeams = TableCount(foundTeams)
    print( "GatherValidTeams - Found spawns for a total of " .. numTeams .. " teams" )
    
    local foundTeamsList = {}
    for t, _ in pairs( foundTeams ) do
        table.insert( foundTeamsList, t )
    end

    if numTeams == 0 then
        print( "GatherValidTeams - NO team spawns detected, defaulting to GOOD/BAD" )
        table.insert( foundTeamsList, DOTA_TEAM_GOODGUYS )
        table.insert( foundTeamsList, DOTA_TEAM_BADGUYS )
        numTeams = 2
    end

    local maxPlayersPerValidTeam = math.floor( 10 / numTeams )

    print( "Setting up teams:" )
    for team = 0, (DOTA_TEAM_COUNT-1) do
        local maxPlayers = 0
        if ( nil ~= TableFindKey( foundTeamsList, team ) ) then
            maxPlayers = maxPlayersPerValidTeam
        end
        print( " - " .. team .. " ( " .. GetTeamName( team ) .. " ) -> max players = " .. tostring(maxPlayers) )
        GameRules:SetCustomGameTeamMaxPlayers( team, maxPlayers )
    end
end

-- function GameMode:OnJungleKilled(keys)
--     local player = EntIndexToHScript( keys.entindex_attacker )
--     local killedUnit = EntIndexToHScript( keys.entindex_killed )
--     local unitName = killedUnit:GetName()

--     local refraction = killedUnit:FindAbilityByName("templar_assassin_refraction_holdout")
--     local buff = killedUnit:FindAbilityByName("venomancer_poison_nova")
--     killedUnit:CastAbilityImmediately(buff, -1 )
--     -- killedUnit:CastAbilityOnTarget(player, refraction, -1 )


--     -- player:AddNewModifier(nil, nil, 'modifier_creep_buff_haste', {duration = 10})
-- end

-- Helper Functions Move to its own file eventually
function TableCount( t )
    local n = 0
    for _ in pairs( t ) do
        n = n + 1
    end
    return n
end

function TableFindKey( table, val )
    if table == nil then
        print( "nil" )
        return nil
    end

    for k, v in pairs( table ) do
        if v == val then
            return k
        end
    end
    return nil
end