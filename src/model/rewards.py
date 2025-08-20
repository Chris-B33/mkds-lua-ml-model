import math

def compute_distance_from_origin_to_line(x1, y1, x2, y2):
    numerator = abs(x2 * y1 - y2 * x1)
    denominator = math.sqrt((y2 - y1) ** 2 + (x2 - x1) ** 2)
    return numerator / denominator

def compute_reward(prev_stats, cur_stats) -> float:
    if len(cur_stats) == 0:
        return 0.0

    reward = 0.0

    # --- Rewards --- #
    # General Progress
    cur_checkpoint = prev_stats["nextCheckpointNum"]
    next_checkpoint = cur_stats["nextCheckpointNum"]
    prev_lap = prev_stats["lap"]
    cur_lap = cur_stats["lap"]
    
    if cur_lap > prev_lap:
        reward += 10.0
    elif next_checkpoint > cur_checkpoint:
        reward += 1.0
    elif next_checkpoint < cur_checkpoint:
        reward -= 2.0
    else:
        c1x, c1y = prev_stats["nextCheckpointP1x"], prev_stats["nextCheckpointP1y"]
        c2x, c2y = cur_stats["nextCheckpointP2x"], cur_stats["nextCheckpointP2y"]
        distance_to_line = compute_distance_from_origin_to_line(c1x, c1y, c2x, c2y)
        reward += (1 - distance_to_line) * 0.3

    # Keeping speed high
    reward += 0.5 * cur_stats["speed"]

    # --- Penalties --- #
    # Driving backwards or turned around on the track
    if cur_stats["speed"] < 0.0 or cur_stats["isGoingBackwards"] == 1:
        reward -= 3.0
    
    # Emulator resets from no progress made
    if cur_stats["episode_done"] == 1:
        reward -= 3.0
    
    return reward
