function CastBuff(data)
  local target = data.caller
  if target ~= nil then
  	-- local attacker = EntIndexToHScript( data.entindex_attacker )
    local buff = thisEntity:FindAbilityByName("venomancer_poison_nova")
    thisEntity:CastAbilityImmediately(buff, -1 )
  end
end

function CastOnDeath(data)
	local player = data.attacker;
	local ability = data.ability;
	local caster = data.caster;
  
	ability:ApplyDataDrivenModifier(caster, player, "modifier_haste_buff", nil)
end

function OnRoshanDeath(data)
  local roshan = data.caster
  local player = data.attacker
  local heroes = HeroList:GetAllHeroes()
  local team = player:GetTeam()
  local game = GameRules:GetGameModeEntity().GameMode
  local NonBallTeamLastHit = true
  local ball = nil;

  for i,hero in pairs(heroes) do
    -- If hero is on the team that got the last hit
    if hero:GetTeam() == team then
      -- If hero is on the team with the ball
      if team == game.teamWithBall then
        -- Give Bonus Points
        NonBallTeamLastHit = false
        game.ballPointTrack[team] = game.ballPointTrack[team] + 15
      end
    end

    -- Check inventory and find the ball
    if hero:HasItemInInventory('item_oddball') then
      for i=0,5 do
        local item = hero:GetItemInSlot(i)
        if item then
          if item:GetName() == 'item_oddball' then
            ball = hero:GetItemInSlot(i)
          end
        end
      end
    end
  end

  if NonBallTeamLastHit then
    -- Delete the ball and respawn it
    if ball == nil then
      UTIL_Remove(game.itemBall)
      UTIL_Remove(game.getDroppedBall())
    else
      hero:RemoveItem(ball)
    end

    -- Resummon the ball
    game:SpawnBall(player:GetAbsOrigin())

    EmitGlobalSound('Oddball.interception')
  end

end