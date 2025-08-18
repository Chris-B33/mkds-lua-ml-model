import math

def dist_origin_to_segment(x1, y1, x2, y2):
    seg_dx = x2 - x1
    seg_dy = y2 - y1

    seg_len_sq = seg_dx**2 + seg_dy**2
    if seg_len_sq == 0:
        return math.sqrt(x1**2 + y1**2)

    t = max(0, min(1, (-x1 * seg_dx - y1 * seg_dy) / seg_len_sq))
    closest_x = x1 + t * seg_dx
    closest_y = y1 + t * seg_dy

    return math.sqrt(closest_x**2 + closest_y**2)


def computes_dist_to_next_checkpoint(stats):
    x1, y1 = stats["nextCheckpointP1x"], stats["nextCheckpointP1y"]
    x2, y2 = stats["nextCheckpointP2x"], stats["nextCheckpointP2y"]
    return dist_origin_to_segment(x1, y1, x2, y2)

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

    dist = computes_dist_to_next_checkpoint(cur_stats)
    dist_pen = 0.01 * dist  

    speed = float(cur_stats["speed"])
    speed_bonus = 1 * max(0.0, speed)  
    backwards_pen = 5.0 if speed < 0 or cur_stats["isGoingBackwards"] == 1 else 0.0

    air_pen = 0.02 * float(cur_stats["framesInAir"])
    episode_done_pen = 50.0 if cur_stats["episode_done"] == 1 else 0.0

    reward = progress - dist_pen + speed_bonus - backwards_pen - air_pen - episode_done_pen
    return reward
