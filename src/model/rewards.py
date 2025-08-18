def compute_progress(prev_stats, cur_stats) -> float:
    if len(prev_stats) == 0 or len(cur_stats) == 0:
        return 0.0
    
    prev_prog = (prev_stats['lap'] * 3) + prev_stats["nextCheckpointNum"] - 1
    curr_prog = (cur_stats['lap'] * 3) + cur_stats["nextCheckpointNum"] - 1

    return float(curr_prog - prev_prog)

def compute_reward(prev_stats, cur_stats) -> float:
    if len(cur_stats) == 0:
        return 0.0
    
    progress = compute_progress(prev_stats, cur_stats) * 5

    speed_term = 0.05 * float(cur_stats["speed"])
    backwards_pen = 0.5 if cur_stats["isGoingBackwards"] > 0.0 else 0.0
    air_pen = 0.02 * float(cur_stats["framesInAir"])
    episode_done_pen = 10.0 if cur_stats["episode_done"] == 1 else 0.0

    reward = progress + speed_term - backwards_pen - air_pen -  episode_done_pen
    return reward
