import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import threading
import time
import random

def run_gui(action_rewards):
    fig, ax = plt.subplots(figsize=(6, 4))
    actions = list(action_rewards.keys())
    rewards = list(action_rewards.values())
    
    bars = ax.bar(actions, rewards, color='skyblue')
    ax.set_ylabel("Reward")
    ax.set_title("RL Actions and Rewards")

    def update(frame):
        rewards = list(action_rewards.values())
        max_index = rewards.index(max(rewards))

        for i, bar in enumerate(bars):
            bar.set_height(rewards[i])
            bar.set_color('yellow' if i == max_index else 'skyblue')

        current_values = list(action_rewards.values())
        ax.set_ylim(min(current_values) * 1.1, max(current_values) * 1.1 if max(current_values)!=0 else 1)
        return bars

    ani = FuncAnimation(fig, update, interval=50, blit=False)
    plt.show()


# Example usage
if __name__ == "__main__":
    rewards = {"left": 0.2, "right": -0.5, "up": 0.1, "down": 0.0}

    # Simulate rewards changing over time
    def simulate_rewards():
        while True:
            for k in rewards:
                rewards[k] += random.uniform(-0.05, 0.05)
            time.sleep(0.05)

    threading.Thread(target=simulate_rewards, daemon=True).start()
    threading.Thread(target=run_gui, args=(rewards,), daemon=True).start()

    # Keep main program running
    while True:
        time.sleep(1)