def compute_progress(prev_stats, cur_stats) -> float:
    if prev_stats is None or cur_stats is None:
        return 0.0
    if "lap" not in prev_stats or "nextCheckpointNum" not in prev_stats:
        print("Missing keys in prev_stats:", prev_stats)
    prev_prog = (prev_stats['lap'] * 3) + prev_stats["nextCheckpointNum"] - 1
    curr_prog = (cur_stats['lap'] * 3) + cur_stats["nextCheckpointNum"] - 1

    return float(curr_prog - prev_prog)

def compute_reward(prev_stats, cur_stats) -> float:
    if cur_stats is None:
        return 0.0
    
    progress = compute_progress(prev_stats, cur_stats) * 5

    speed_term = 0.05 * float(cur_stats["speed"])
    backwards_pen = 0.5 if cur_stats["isGoingBackwards"] > 0.0 else 0.0
    air_pen = 0.02 * float(cur_stats["framesInAir"])

    reward = progress + speed_term - backwards_pen - air_pen
    return reward
