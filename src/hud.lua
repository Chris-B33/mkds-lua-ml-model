local m = {}

function m.drawHUD(stats)
	if not stats then
		gui.text(5, 595, "No racer data")
		return
	end
	
	gui.text(5, 565, "Speed: " .. stats.speed)
	gui.text(5, 580, string.format("Pos: x=%d y=%d z=%d", stats.x, stats.y, stats.z))
	gui.text(5, 595, "Angle: " .. stats.drift_angle)

	gui.text(5, 550, string.format("Grounded: %s, framesInAir=%d", stats.isGrounded, stats.framesInAir))
	gui.text(5, 535, string.format("Going Backwards: %s", stats.isGoingBackwards))

	gui.text(5, 520, string.format("Checkpoint: %s", stats.checkpoint))
	gui.text(5, 505, string.format("Key Checkpoint: %s", stats.keyCheckpoint))
	gui.text(5, 490, string.format("Lap: %s", stats.lap))
end

return m