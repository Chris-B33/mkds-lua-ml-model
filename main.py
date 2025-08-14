import threading
import numpy as np

from src.model.agent import DQNAgent
from src.model import config as C
from src.model.gui import run_gui
from src.model.interface import open_rom, read_stats, write_ctrls
from src.model.rewards import compute_reward

action_rewards = dict.fromkeys(C.ACTIONS.keys(), 0.0) # needs to be modified in main somehow

def stats_to_state(stats_dict):
    if len(stats_dict) == 0: return None
    return np.array([float(stats_dict[k]) for k in C.STAT_KEYS], dtype=np.float32)

def action_to_controls(action_idx):
    controls = {"A": 0, "B": 0, "Left": 0, "Right": 0}
    controls.update(list(C.ACTIONS.values())[action_idx])
    return controls

def main():
    #open_rom(C.EMU_PATH, C.ROM_PATH)

    print("Loading agent...")
    state_dim = len(C.STAT_KEYS)
    n_actions = len(C.ACTIONS)
    agent = DQNAgent(state_dim, n_actions)
    agent.load(C.CHECKPOINT_PATH)

    prev_stats = None
    prev_state = None
    prev_action = None

    i = 0
    while True:
        print("Running model" + "." * (i // 1000), end="\r")
        i += 1
        if i > 3000: 
            i = 0
            print("                     ", end="\r")
            
        stats = read_stats(C.STATS_FILE)
        if stats is None or stats == prev_stats: continue

        state = stats_to_state(stats)
        if state is None: continue

        action_idx = agent.act(state)
        controls = action_to_controls(action_idx)
        write_ctrls(C.CONTROLS_FILE, controls)

        next_stats = read_stats(C.STATS_FILE)
        
        if next_stats is not None:
            reward = compute_reward(prev_stats, next_stats) if prev_stats is not None else 0.0
            next_state = stats_to_state(next_stats)
            done = False

            if prev_state is not None and prev_action is not None:
                agent.remember(prev_state, prev_action, reward, next_state, done)
                agent.train_step()

            prev_stats = next_stats
            prev_state = next_state
            prev_action = action_idx

        if agent.steps % C.SAVE_EVERY_STEPS == 0 and agent.steps > 0:
            agent.save(C.CHECKPOINT_PATH)

if __name__ == "__main__":
    main_thread = threading.Thread(target=main, daemon=True)
    main_thread.start()
    run_gui(action_rewards)