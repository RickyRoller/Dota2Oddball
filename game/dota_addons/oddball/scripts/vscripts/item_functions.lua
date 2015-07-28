if itemFunctions == nil then
	print ( '[ItemFunctions] creating itemFunctions' )
	itemFunctions = {} -- Creates an array to let us beable to index itemFunctions when creating new functions
	itemFunctions.__index = itemFunctions
end
 
function itemFunctions:new() -- Creates the new class
	print ( '[ItemFunctions] itemFunctions:new' )
	o = o or {}
	setmetatable( o, itemFunctions )
	return o
end
 
function itemFunctions:start() -- Runs whenever the itemFunctions.lua is ran
	print('[ItemFunctions] itemFunctions started!')
end
 
function DropBallOnDeath(keys) -- keys is the information sent by the ability
	local game = GameRules:GetGameModeEntity().GameMode
	EmitBallDropSounds(keys.caster, keys.caster:GetTeam())
	print( '[ItemFunctions] DropItemOnDeath Called' )
	local killedUnit = EntIndexToHScript( keys.caster_entindex ) -- EntIndexToHScript takes the keys.caster_entindex, which is the number assigned to the entity that ran the function from the ability, and finds the actual entity from it.
	local itemName = tostring(keys.ability:GetAbilityName()) -- In order to drop only the item that ran the ability, the name needs to be grabbed. keys.ability gets the actual ability and then GetAbilityName() gets the configname of that ability such as juggernaut_blade_dance.
	if killedUnit:IsHero() or killedUnit:HasInventory() then -- In order to make sure that the unit that died actually has items, it checks if it is either a hero or if it has an inventory.
		for itemSlot = 0, 5, 1 do --a For loop is needed to loop through each slot and check if it is the item that it needs to drop
	        	if killedUnit ~= nil then --checks to make sure the killed unit is not nonexistent.
                		local Item = killedUnit:GetItemInSlot( itemSlot ) -- uses a variable which gets the actual item in the slot specified starting at 0, 1st slot, and ending at 5,the 6th slot.
                		if Item ~= nil and Item:GetName() == itemName then -- makes sure that the item exists and making sure it is the correct item
                				game:SpawnBall(killedUnit:GetOrigin())
                    			killedUnit:RemoveItem(Item) -- finally, the item is removed from the original units inventory.
                		end
	        	end
		end
	end
end

function EmitBallDropSounds(player, team)
	local heroes = HeroList:GetAllHeroes()

	for i,hero in pairs(heroes) do
		if hero:GetTeam() ~= team then
			EmitSoundOnClient('Oddball.enemyDroppedBall', hero:GetPlayerOwner())
		end
	end

	EmitSoundOnLocationForAllies(player:GetAbsOrigin(), 'Oddball.teamDroppedBall', player)
end

function IncrementScore(data)
	local game = GameRules:GetGameModeEntity().GameMode
	local caster = data.caster
	local team = caster:GetTeam()
	local remainingPoints = 0

	GameRules:AddMinimapDebugPoint( 0, caster:GetAbsOrigin(), 0, 0, 0, 0, 0 )

	game.teamWithBall = team

	-- If the team that picks up the ball is either radiant or dire
	if team == 2 or team == 3 then
		-- Assign the points to the carriers team
		local points = game.PointBonus[team] + 1
		game.Points[team] = game.Points[team] + points
		remainingPoints = game.POINTS_TO_WIN - game.Points[team]
		CustomNetTables:SetTableValue( "game_state", "teamPoints", {radiant = game.Points[2], dire = game.Points[3]} )

		-- Update the points tracking for ball respawn
		game.ballPointTrack[team] = game.Points[team] + 1

		-- Reset the ball timer
		game.ballInitialPickup = true
		game.ballResapwnTimer = 0
	end

	-- Check to see if anyone has won
	if remainingPoints == 0 then
		GameRules:SetGameWinner( team )
	end

	-- Show the ball on the minimap
    game:ShowBallOnMinimap(caster:GetAbsOrigin().x, caster:GetAbsOrigin().y)

	return 1
end

function PassBall(data)
	local target = data.target
	local caster = data.caster

	for i=0,5 do
		local item = caster:GetItemInSlot(i)
		if item then
			if item:GetName() == 'item_oddball' then
				if target:HasAnyAvailableInventorySpace() then
					AddNewBallRemoveOld(target, caster, item)
        			EmitSoundOnClient('Oddball.youHaveBall', target:GetPlayerOwner())
				else
					DropTheBall(target, caster, item, target:GetAbsOrigin())
				end
			end
		end
	end
end

function AddNewBallRemoveOld(target, caster, item)
	target:AddItemByName('item_oddball')
	for i=0,5 do
		local newItem = target:GetItemInSlot(i)
		if newItem then
			if newItem:GetName()  == 'item_oddball' then
				newItem:StartCooldown(15)
			end
		end
	end
	caster:RemoveItem(item)
end

function DropTheBall(target, caster, item, location)
	local game = GameRules:GetGameModeEntity().GameMode
	
	caster:RemoveItem(item)
	game:SpawnBall(location)
	EmitBallDropSounds(target, target:GetTeam())
end

function CalcBallDropLocation(data)
	local distance = 1200;
	local caster = data.caster
	local origin = caster:GetAbsOrigin()
	local forwardDirection = caster:GetForwardVector():Normalized()

	itemFunctions.ballDropLocation = origin + distance * forwardDirection
    EmitGlobalSound('Oddball.ballThrown') 
end

function BallMissed(data)
	local caster = data.caster

	for i=0,5 do
		local item = caster:GetItemInSlot(i)
		if item then
			if item:GetName() == 'item_oddball' then
				DropTheBall(caster, caster, item, itemFunctions.ballDropLocation)
			end
		end
	end
end