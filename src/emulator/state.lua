local m = {}

local FRAME_LIMIT = 300

local SLOWNESS_FRAME_COUNT = 0

local NO_PROGRESS_FRAME_COUNT = 0
local last_checkpoint = 0

function m.needsReset(stats)
    -- Low speed = reset
	if stats.speed < 0.7 then
		SLOWNESS_FRAME_COUNT = SLOWNESS_FRAME_COUNT + 1
	else 
	    SLOWNESS_FRAME_COUNT = 0
	end

    -- No checkpoint progress or going backwards = reset
    if stats.nextCheckpointNum == last_checkpoint or stats.isGoingBackwards == 1 then 
        NO_PROGRESS_FRAME_COUNT = NO_PROGRESS_FRAME_COUNT + 1
    else
        NO_PROGRESS_FRAME_COUNT = 0
    end
    last_checkpoint = stats.nextCheckpointNum

	if SLOWNESS_FRAME_COUNT > FRAME_LIMIT 
    or NO_PROGRESS_FRAME_COUNT > FRAME_LIMIT then
        SLOWNESS_FRAME_COUNT = 0
        NO_PROGRESS_FRAME_COUNT = 0
        return true
    end
    return false
end

return m