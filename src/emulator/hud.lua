local m = {}

function m.drawHUD(stats)
	if not stats then
		gui.text(5, 595, "No racer data")
		return
	end
	
	gui.text(5, 495, string.format("Lap: %s", stats.lap))
	gui.text(5, 510, string.format("Next Checkpoint: %s", stats.nextCheckpointNum))
	gui.text(5, 525, string.format("Coordinates: {%s, %s}, {%s, %s}", 
		stats.nextCheckpointP1.x,
		stats.nextCheckpointP1.y,
		stats.nextCheckpointP2.x,
		stats.nextCheckpointP2.y
	))

	gui.text(5, 565, "Speed: " .. stats.speed)
	gui.text(5, 580, "Angle: " .. stats.drift_angle)

	gui.text(5, 595, string.format("Grounded: %s, framesInAir=%d", stats.isGrounded, stats.framesInAir))
	gui.text(5, 610, string.format("Going Backwards: %s", stats.isGoingBackwards))
end

return m