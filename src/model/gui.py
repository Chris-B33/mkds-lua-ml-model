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
    ax.axhline(0, color='black', linewidth=1)
    ax.set_ylabel("Rewards")
    ax.set_title("Actions")

    ax.set_xticklabels([f"{a}\n{r:.2f}" for a, r in zip(actions, rewards)])

    def update(frame):
        rewards = list(action_rewards.values())
        max_index = rewards.index(max(rewards))

        for i, bar in enumerate(bars):
            bar.set_height(rewards[i])
            if i == max_index: bar.set_color('yellow')
            elif rewards[i] < 0: bar.set_color('red')
            else: bar.set_color('skyblue')

        current_values = list(action_rewards.values())
        ax.set_xticks(range(len(actions)))
        ax.set_xticklabels([f"{a}\n{r:.2f}" for a, r in zip(actions, rewards)])
        ax.set_ylim(min(current_values), max(current_values) * 1.1 if max(current_values)!=0 else 1)
        return bars

    ani = FuncAnimation(fig, update, interval=50, blit=False)
    plt.show()

if __name__ == "__main__":
    rewards = {"left": 1, "right": 1, "up": 1, "down": 0.0}

    def simulate_rewards():
        while True:
            for k in rewards:
                rewards[k] += random.uniform(-0.055, 0.05)
            time.sleep(0.05)

    threading.Thread(target=simulate_rewards, daemon=True).start()
    run_gui(rewards)