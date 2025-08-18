import random
from collections import deque
import numpy as np

class ReplayBuffer:
    def __init__(self, capacity):
        self.buf = deque(maxlen=capacity)

    def push(self, s, a, r, ns, done):
        s = np.array(s, dtype=np.float32).ravel()
        ns = np.array(ns, dtype=np.float32).ravel()
        self.buf.append((s, a, r, ns, done))

    def sample(self, batch_size):
        if len(self.buf) < batch_size:
            return None

        batch = random.sample(self.buf, batch_size)
        s, a, r, ns, d = zip(*batch)

        s = np.stack(s, axis=0)
        ns = np.stack(ns, axis=0)
        a = np.array(a, dtype=np.int64)
        r = np.array(r, dtype=np.float32)
        d = np.array(d, dtype=np.float32)

        return s, a, r, ns, d

    def __len__(self):
        return len(self.buf)