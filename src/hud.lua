local m = {}

function m.drawHUD(stats)
	if not stats then
		gui.text(5, 595, "No racer data")
		return
	end
	
	gui.text(5, 390, string.format("Lap: %s", stats.lap))
	gui.text(5, 405, string.format("Next Checkpoint: %s", stats.nextCheckpointNum))
	gui.text(5, 420, string.format("Coordinates: {%s, %s}, {%s, %s}", 
		stats.nextCheckpointP1x,
		stats.nextCheckpointP1y,
		stats.nextCheckpointP2x,
		stats.nextCheckpointP2y
	))

	gui.text(5, 565, "Speed: " .. stats.speed)
	gui.text(5, 580, string.format("Pos: x=%d y=%d z=%d", stats.x, stats.y, stats.z))
	gui.text(5, 595, "Angle: " .. stats.drift_angle)

	gui.text(5, 550, string.format("Grounded: %s, framesInAir=%d", stats.isGrounded, stats.framesInAir))
	gui.text(5, 535, string.format("Going Backwards: %s", stats.isGoingBackwards))
end

return m