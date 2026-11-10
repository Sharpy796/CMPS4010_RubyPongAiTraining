import socket
import json
import random
import os
import signal
import sys
from collections import deque
import torch
import torch.nn as nn
import torch.optim as optim

# ---------------------------------------------------------
# 1. Configuration & Hyperparameters
# ---------------------------------------------------------
HOST = '127.0.0.1'
PORT = 65433  # Dedicated port for Connect 4 AI
MODEL_PATH = "connect4_ai.pth"

TRAINING = True

ROWS = 6
COLS = 7
STATE_SIZE = ROWS * COLS  # 42 board cells
ACTION_SIZE = COLS        # 7 columns to drop into

GAMMA = 0.99
LR = 0.001
MEMORY_SIZE = 20000
BATCH_SIZE = 64
EPSILON_START = 1.00
EPSILON_END = 0.05
EPSILON_DECAY = 0.9995

# ---------------------------------------------------------
# 2. PyTorch Neural Network Architecture
# ---------------------------------------------------------
class Connect4DQN(nn.Module):
    def __init__(self):
        super(Connect4DQN, self).__init__()
        self.fc1 = nn.Linear(STATE_SIZE, 128)
        self.fc2 = nn.Linear(128, 128)
        self.fc3 = nn.Linear(128, ACTION_SIZE)

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return self.fc3(x)

# ---------------------------------------------------------
# 3. DQN Agent Class
# ---------------------------------------------------------
class Connect4Agent:
    def __init__(self):
        self.model = Connect4DQN()
        self.optimizer = optim.Adam(self.model.parameters(), lr=LR)
        self.criterion = nn.MSELoss()
        self.memory = deque(maxlen=MEMORY_SIZE)
        self.epsilon = EPSILON_START

        # Load existing weights if present
        if os.path.exists(MODEL_PATH):
            try:
                self.model.load_state_dict(torch.load(MODEL_PATH))
                self.epsilon = 0.20  # Start with higher exploitation if pre-trained
                print(f"Loaded existing model weights from '{MODEL_PATH}'!")
            except Exception as e:
                print(f"Could not load '{MODEL_PATH}': {e}. Starting fresh.")

    def get_valid_actions(self, grid):
        """Returns list of column indices where top row is empty"""
        return [c for c in range(COLS) if grid[0][c] is None]

    def get_action(self, state_tensor, valid_actions):
        if not valid_actions:
            return 0

        # Epsilon-Greedy Action Selection
        if random.random() < self.epsilon:
            return random.choice(valid_actions)
        else:
            with torch.no_grad():
                q_values = self.model(state_tensor).squeeze(0)
                # Mask out full columns
                for c in range(ACTION_SIZE):
                    if c not in valid_actions:
                        q_values[c] = -1e9
                return int(torch.argmax(q_values).item())

    def store_transition(self, state, action, reward, next_state, done):
        self.memory.append((state, action, reward, next_state, done))

    def train_step(self):
        if len(self.memory) < BATCH_SIZE:
            return

        batch = random.sample(self.memory, BATCH_SIZE)
        states, actions, rewards, next_states, dones = zip(*batch)

        state_batch = torch.tensor(states, dtype=torch.float32)
        action_batch = torch.tensor(actions, dtype=torch.int64).unsqueeze(1)
        reward_batch = torch.tensor(rewards, dtype=torch.float32).unsqueeze(1)
        next_state_batch = torch.tensor(next_states, dtype=torch.float32)
        done_batch = torch.tensor(dones, dtype=torch.float32).unsqueeze(1)

        # Q(s, a)
        q_values = self.model(state_batch).gather(1, action_batch)

        # Target Q = r + gamma * max(Q(s'))
        with torch.no_grad():
            next_q_values = self.model(next_state_batch).max(1)[0].unsqueeze(1)
            target_q = reward_batch + (1 - done_batch) * GAMMA * next_q_values

        loss = self.criterion(q_values, target_q)
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        # Decay epsilon
        if self.epsilon > EPSILON_END:
            self.epsilon *= EPSILON_DECAY

    def save_weights(self):
        torch.save(self.model.state_dict(), MODEL_PATH)
        print(f"--> Saved weights checkpoint to '{MODEL_PATH}'")


def grid_to_vector(grid):
    flat = []
    for r in range(ROWS):
        for c in range(COLS):
            val = grid[r][c]
            if val == 2:
                flat.append(1.0)
            elif val == 1:
                flat.append(-1.0)
            else:
                flat.append(0.0)
    return flat


# ---------------------------------------------------------
# 4. Main Server Loop
# ---------------------------------------------------------
if __name__ == '__main__':
    agent = Connect4Agent()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, PORT))

    print(f"============================================")
    print(f"Connect 4 PyTorch AI Server Listening on {HOST}:{PORT}")
    print(f"Will auto-save '{MODEL_PATH}' after every match and on exit.")
    print(f"============================================")

    last_state = None
    last_action = None
    games_played = 0

    # Handle termination signals cleanly (Ctrl+C, kill, terminal close)
    running = [True]

    def handle_exit(signum, frame):
        running[0] = False
        print(f"\n[Signal {signum}] Shutting down Connect 4 AI Server...")
        if TRAINING:
            agent.save_weights()
            print("Model weights safely saved on shutdown.")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    try:
        while running[0]:
            try:
                raw_data, addr = sock.recvfrom(2048)
                data = json.loads(raw_data.decode('utf-8'))

                grid = data['grid']
                winner = data.get('winner')
                game_over = data.get('game_over', False)
                current_state = grid_to_vector(grid)
                current_state_tensor = torch.tensor(current_state, dtype=torch.float32).unsqueeze(0)

                # Compute Reward for AI (Player 2)
                reward = 0.0
                done = False

                if winner == 2:
                    reward = 100.0
                    done = True
                    games_played += 1
                    print(f"[Game {games_played}] AI (Player 2) WON! (Epsilon: {agent.epsilon:.4f})")
                elif winner == 1:
                    reward = -100.0
                    done = True
                    games_played += 1
                    print(f"[Game {games_played}] AI LOST to Player 1! (Epsilon: {agent.epsilon:.4f})")
                elif winner == 'draw':
                    reward = 10.0
                    done = True
                    games_played += 1
                    print(f"[Game {games_played}] DRAW! (Epsilon: {agent.epsilon:.4f})")
                else:
                    reward = 0.5

                # Experience Replay Training Step
                if last_state is not None and last_action is not None and TRAINING:
                    agent.store_transition(last_state, last_action, reward, current_state, done)
                    agent.train_step()

                if done:
                    last_state = None
                    last_action = None
                    if TRAINING:
                        agent.save_weights()  # Auto-save at the end of every game!
                    continue

                # Pick next action if it's AI's turn
                valid_actions = agent.get_valid_actions(grid)
                action = agent.get_action(current_state_tensor, valid_actions)

                last_state = current_state
                last_action = action

                # Send column selection back to Ruby
                sock.sendto(str(action).encode('utf-8'), addr)

            except Exception as e:
                print(f"Loop Warning: {e}")

    except KeyboardInterrupt:
        print("\nStopping Connect 4 AI Server...")
    finally:
        if TRAINING:
            agent.save_weights()
            print("Model weights safely saved on shutdown.")
