import torch, time
import threading
import numpy as np
from datetime import datetime

from src.model.agent import DQNAgent
from src.model import config as C
from src.model.gui import run_gui
from src.model.interface import open_rom, read_stats, write_ctrls
from src.model.rewards import compute_reward
from src.model.server import Server

action_rewards = dict.fromkeys(C.ACTIONS.keys(), 0.0) # needs to be modified in main somehow

def stats_to_state(stats_dict):
    if len(stats_dict) == 0: return None
    return np.array([float(stats_dict[k]) for k in C.STAT_KEYS], dtype=np.float32)

def update_rewards(new_rewards):
    for key, val in zip(action_rewards.keys(), new_rewards):
        action_rewards[key] = val

def main():
    print("Initializing server and emulator...")
    server = Server(C.SOCKET_HOST, int(C.SOCKET_PORT))
    open_rom(C.EMU_PATH, C.ROM_PATH, C.SOCKET_HOST, C.SOCKET_PORT)
    server.accept_connection()

    print("Loading agent...")
    state_dim = len(C.STAT_KEYS)
    n_actions = len(C.ACTIONS)
    agent = DQNAgent(state_dim, n_actions)
    agent.load(C.CHECKPOINT_PATH)

    prev_stats = None
    prev_state = None
    prev_action = None

    while True:
        stats = server.read_stats()
        if not stats:
            continue

        state = stats_to_state(stats)
        if len(state) == 0:
            continue

        rewards_tensor = agent.act(state)
        action_idx = int(torch.argmax(rewards_tensor, dim=1).item())

        server.send_action(action_idx)

        rewards_list = rewards_tensor.detach().numpy().tolist()[0]
        update_rewards(rewards_list)

        if prev_stats is not None and prev_state is not None and prev_action is not None:
            reward = compute_reward(prev_stats, stats)
            next_state = state
            done = False
            agent.remember(prev_state, prev_action, reward, next_state, done)
            agent.train_step()
            prev_state = next_state
            prev_action = action_idx
            prev_stats = stats
        else:
            prev_state = state
            prev_action = action_idx
            prev_stats = stats

        if agent.steps % C.SAVE_EVERY_STEPS == 0 and agent.steps > 0:
            agent.save(C.CHECKPOINT_PATH)
            print(f"{datetime.now().strftime('%H:%M:%S')} [SAVE]: Model saved to '{C.CHECKPOINT_PATH}'")

if __name__ == "__main__":
    main_thread = threading.Thread(target=main, daemon=True)
    main_thread.start()
    run_gui(action_rewards)