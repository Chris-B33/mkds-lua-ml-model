import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
from .replay import ReplayBuffer
from . import config as C

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

class QNet(nn.Module):
    def __init__(self, input_dim, output_dim, hidden=128):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden),
            nn.ReLU(),
            nn.Linear(hidden, hidden),
            nn.ReLU(),
            nn.Linear(hidden, output_dim)
        )
    def forward(self, x):
        return self.net(x)

class DQNAgent:
    def __init__(self, state_dim, n_actions):
        self.state_dim = state_dim
        self.n_actions = n_actions

        self.q_online = QNet(state_dim, n_actions).to(device)
        self.q_target = QNet(state_dim, n_actions).to(device)
        self.q_target.load_state_dict(self.q_online.state_dict())
        self.q_target.eval()

        self.optim = optim.Adam(self.q_online.parameters(), lr=C.LR)
        self.replay = ReplayBuffer(C.REPLAY_SIZE)

        self.steps = 0

    def epsilon(self):
        eps = C.EPS_END + max(0.0, (C.EPS_START - C.EPS_END) * (1 - self.steps / C.EPS_DECAY_FRAMES))
        return float(max(C.EPS_END, eps))

    def act(self, state_vec):
        self.steps += 1
        if np.random.rand() < self.epsilon():
            return np.random.randint(self.n_actions)
        with torch.no_grad():
            s = torch.tensor(state_vec, dtype=torch.float32, device=device).unsqueeze(0)
            q = self.q_online(s)
            return int(torch.argmax(q, dim=1).item())

    def remember(self, s, a, r, ns, done):
        self.replay.push(s, a, r, ns, done)

    def train_step(self):
        if len(self.replay) < C.MIN_REPLAY_TO_TRAIN:
            return

        s, a, r, ns, d = self.replay.sample(C.BATCH_SIZE)

        s  = torch.tensor(s,  dtype=torch.float32, device=device)
        ns = torch.tensor(ns, dtype=torch.float32, device=device)
        a  = torch.tensor(a,  dtype=torch.int64,   device=device).unsqueeze(1)
        r  = torch.tensor(r,  dtype=torch.float32, device=device).unsqueeze(1)
        d  = torch.tensor(d,  dtype=torch.float32, device=device).unsqueeze(1)

        qsa = self.q_online(s).gather(1, a)

        with torch.no_grad():
            max_q_next = self.q_target(ns).max(dim=1, keepdim=True)[0]
            target = r + (1.0 - d) * C.GAMMA * max_q_next

        loss = nn.SmoothL1Loss()(qsa, target)
        self.optim.zero_grad()
        loss.backward()
        nn.utils.clip_grad_norm_(self.q_online.parameters(), 10.0)
        self.optim.step()

        if self.steps % C.TARGET_UPDATE_INTERVAL == 0:
            self.q_target.load_state_dict(self.q_online.state_dict())

    def save(self, path):
        import os
        os.makedirs(os.path.dirname(path), exist_ok=True)
        torch.save({
            "model": self.q_online.state_dict(),
            "steps": self.steps
        }, path)

    def load(self, path):
        import os
        if not os.path.exists(path):
            return
        ckpt = torch.load(path, map_location=device)
        self.q_online.load_state_dict(ckpt["model"])
        self.q_target.load_state_dict(self.q_online.state_dict())
        self.steps = ckpt.get("steps", 0)