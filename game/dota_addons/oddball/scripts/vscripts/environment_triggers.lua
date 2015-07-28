
function BuffPadTrigger(event)
	local pad = event.caller
	local activator = event.activator
	local game = GameRules:GetGameModeEntity().GameMode

	local currentGameTime = GameRules:GetDOTATime(false, false)

	if pad.offCooldown == nil then
		pad.offCooldown = currentGameTime
	end

	-- If the pad ability is off cooldown
	if currentGameTime >= pad.offCooldown then
		local buffName = GetTeamBuff(activator:GetTeam())			

		local globalUnit = game.GlobalAbilityUnit

		local ability = globalUnit:FindAbilityByName('buff_pad_abilities')
		local team = activator:GetTeam()
		local heroes = HeroList:GetAllHeroes()

		for i,hero in pairs(heroes) do
			-- If the hero is on the same team as the hero that triggered the pad
			if hero:GetTeam() == team then
				ability:ApplyDataDrivenModifier(globalUnit, hero, buffName, nil)

				-- Delete the particle on the pad
				local particleEnt = Entities:FindByClassnameWithin(nil, 'info_particle_system', pad:GetAbsOrigin(), 250)
				UTIL_Remove(particleEnt)
			end
		end

		pad.offCooldown = currentGameTime + game.buffPadCooldown

		Timers:CreateTimer({
		    endTime = game.buffPadCooldown,
		    callback = function()
		    	local partEnt = Entities:CreateByClassname('info_particle_system')
		    	partEnt:SetOrigin(pad:GetAbsOrigin());

				local nFXIndex = ParticleManager:CreateParticle( "particles/econ/events/league_teleport_2014/teleport_end_volume_magic_league.vpcf", PATTACH_CUSTOMORIGIN, partEnt )
				ParticleManager:SetParticleControl( nFXIndex, 0, pad:GetOrigin() )
				ParticleManager:SetParticleControl( nFXIndex, 1, Vector( 35, 35, 25 ) )
				ParticleManager:ReleaseParticleIndex( nFXIndex )
		    end
		  })
	end
end


function GetTeamBuff(team)
	local game = GameRules:GetGameModeEntity().GameMode
	local buffName = ''
	local buffs = {}
	local carrierBuffs = {
		'modifier_team_haste'
		-- , 'modifier_team_mek'
	}
	local nonCarrierBuffs = {
		'modifier_team_haste'
		-- , 'modifier_team_summon_bird'
	}

	if game.teamWithBall == team then
		buffs = carrierBuffs
	else
		buffs = nonCarrierBuffs
	end

	buffName = GetRandomBuff(nonCarrierBuffs)

	return buffName
end

function GetRandomBuff(buffs)
	local index = RandomInt( 1, table.getn(buffs) )
	return buffs[index]
end