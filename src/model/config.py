EMU_PATH = "./EmuHawk.exe"
LUA_SCRIPT_PATH = "mkds-lua-ml-model/src/MKDS Info.lua"
ROM_PATH = "ROMs/Mario Kart DS (USA, Australia) (En,Fr,De,Es,It).nds"

STATS_FILE = "mkds-lua-ml-model/data/cur_stats.dat"   
CONTROLS_FILE = "mkds-lua-ml-model/data/new_ctrls.dat"

STAT_KEYS = [
    "speed",
    "acceleration",
    "dx", "dy", "dz",
    "drift_angle", "delta_drift_angle",
    "framesInAir",
    "isGrounded", "isGoingBackwards",
    "nextCheckpointNum",
    "nextCheckpointP1x", "nextCheckpointP1y",
    "nextCheckpointP2x", "nextCheckpointP2y",
    "lap",
]

ACTIONS = [
    {"A":1, "B":0, "Left":1, "Right":0},  # throttle + steer left
    {"A":1, "B":0, "Left":0, "Right":0},  # throttle + straight
    {"A":1, "B":0, "Left":0, "Right":1},  # throttle + steer right
    {"A":0, "B":1, "Left":0, "Right":0},  # brake
]

# Hyperparameters
GAMMA = 0.99
LR = 1e-3
BATCH_SIZE = 64
REPLAY_SIZE = 50_000
MIN_REPLAY_TO_TRAIN = 2_000

# Exploration
EPS_START = 1.0
EPS_END = 0.1
EPS_DECAY_FRAMES = 100_000

# Loop control
TARGET_UPDATE_INTERVAL = 2_000 
MAX_NOOP_SKIP = 0               
SAVE_EVERY_STEPS = 20_000
CHECKPOINT_PATH = "mkds-lua-ml-model/data/dqn_latest.pt"