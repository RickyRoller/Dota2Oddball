

function OnStartTouch(trigger)
	print('Out Of Bounds!')
	EmitGlobalSound( "ui.npe_objective_complete" )
end

function OnEndTouch(trigger)
	print('Out Of Bounds!')
	EmitGlobalSound( "ui.npe_objective_given" )
end