import socket
import json
import random
import torch
import torch.nn as nn
import torch.optim as optim
from collections import deque
import os
import random
# ---------------------------------------------------------
# 1. Configuration & Hyperparameters
# ---------------------------------------------------------
HOST = '127.0.0.1'
PORT = 65432

# Hyperparameters for Deep Q-Learning
GAMMA = 0.99            # Discount factor for future rewards
LR = 0.001              # Learning rate
MEMORY_SIZE = 10000     # Replay buffer capacity
BATCH_SIZE = 32         # Batch size for training
EPSILON_START = 1       # Starting randomness (100% random moves initially)
EPSILON_END = 0.05      # Minimum randomness (5% random moves when trained)
EPSILON_DECAY = 0.9995 #0.9995  # Decay rate per frame

# Select difficulty: 'easy', 'medium', or 'hard'
DIFFICULTY = 'hard'

# ---------------------------------------------------------
# 2. PyTorch Neural Network Architecture
# ---------------------------------------------------------
class PongDQN(nn.Module):
    def __init__(self):
        super(PongDQN, self).__init__()
        # Input state vector size = 5: [ball_x, ball_y, ball_x_speed, ball_y_speed, paddle_y, paused]
        self.fc1 = nn.Linear(6, 64)
        self.fc2 = nn.Linear(64, 64)
        self.fc3 = nn.Linear(64, 3) # Output Q-values for 3 actions: [0: 'none', 1: 'up', 2: 'down']

    def forward(self, x):
        x = torch.relu(self.fc1(x))
        x = torch.relu(self.fc2(x))
        return self.fc3(x)

# ---------------------------------------------------------
# 3. DQN Agent Class
# ---------------------------------------------------------
class DQNAgent:
    def __init__(self):
        self.model = PongDQN()
        self.optimizer = optim.Adam(self.model.parameters(), lr=LR)
        self.criterion = nn.MSELoss()
        self.memory = deque(maxlen=MEMORY_SIZE)
        self.epsilon = EPSILON_START
        self.actions = ['none', 'up', 'down']

    def get_action(self, state_tensor, difficulty='hard'):
        # Difficulty adjustment via Epsilon overrides
        if difficulty == 'easy':
            effective_epsilon = max(0.40, self.epsilon)
        elif difficulty == 'medium':
            effective_epsilon = max(0.20, self.epsilon)
        else:
            effective_epsilon = self.epsilon

        # Epsilon-Greedy Action Selection
        if random.random() < effective_epsilon:
            return random.randint(0, 2)  # Pick random action
        else:
            with torch.no_grad():
                q_values = self.model(state_tensor)
                return torch.argmax(q_values).item()

    def store_transition(self, state, action, reward, next_state, done):
        self.memory.append((state, action, reward, next_state, done))

    def train_step(self):
        if len(self.memory) < BATCH_SIZE:
            return  # Wait until we have enough experience stored

        # Sample a random minibatch from replay memory
        batch = random.sample(self.memory, BATCH_SIZE)
        states, actions, rewards, next_states, dones = zip(*batch)

        states = torch.tensor(states, dtype=torch.float32)
        actions = torch.tensor(actions, dtype=torch.long).unsqueeze(1)
        rewards = torch.tensor(rewards, dtype=torch.float32)
        next_states = torch.tensor(next_states, dtype=torch.float32)
        dones = torch.tensor(dones, dtype=torch.float32)

        # Get current Q values predicted by the model
        current_q = self.model(states).gather(1, actions).squeeze(1)

        # Calculate max Q value for next states
        with torch.no_grad():
            max_next_q = self.model(next_states).max(1)[0]
            target_q = rewards + (1 - dones) * GAMMA * max_next_q

        # Compute loss and perform gradient descent step
        loss = self.criterion(current_q, target_q)
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        # Decay epsilon to reduce randomness over time
        if self.epsilon > EPSILON_END:
            self.epsilon *= EPSILON_DECAY

# ---------------------------------------------------------
# 4. UDP Socket Server Setup
# ---------------------------------------------------------
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((HOST, PORT))
print(f"PyTorch AI Server listening on {HOST}:{PORT}...")

agent = DQNAgent()

import os

agent = DQNAgent()

# Load saved weights if they exist
if os.path.exists("pong_ai.pth"):
    agent.model.load_state_dict(torch.load("pong_ai.pth"))
    agent.model.eval() # Set to evaluation mode if desired
    print("Loaded existing model weights from 'pong_ai.pth'!")
else:
    print("No saved weights found. Starting fresh training session.")

# State Tracking Variables
last_state = None
last_action = 0
prev_p2_score = 0
prev_p1_score = 0

def extract_state_vector(data):
    return [
        float(data['ball_x']),
        float(data['ball_y']),
        float(data['ball_x_speed']),
        float(data['ball_y_speed']),
        float(data['paddle_y']),
        bool(data['paused']) # unused if countdown is unused
    ]

# ---------------------------------------------------------
# 5. Main AI Loop
# ---------------------------------------------------------
while True:
    try:
        # Receive JSON string from Ruby
        raw_data, addr = sock.recvfrom(1024)
        data = json.loads(raw_data.decode('utf-8'))

        current_state = extract_state_vector(data)
        current_state_tensor = torch.tensor(current_state, dtype=torch.float32)

        # Reward Calculation Strategy
        reward = 0
        done = False

        # rewards for:
        # - moving toward the ball
        # - bouncing the ball (!!!!)

        # penalties for:
        # - moving away from the ball
        # - letting the ball get away

        # neutral for:
        # - if the countdown is running ('paused')
        #   - ('paused' isn't being used bc training is faster without a countdown lol)


        if (not data['paused']):
            if data['ball_x'] >= 610: # past paddle, game lost
                reward = -1000
                print("HEY YOU LOST")
                done = True
            else:
                if (data['ball_y'] < data['paddle_y']): # above paddle
                    if (last_action == 1): # moving up
                        reward += 1
                    else:
                        reward -= 2
                elif (data['ball_y']-15 > data['paddle_y']+100): # below paddle
                    if (last_action == 2): # moving down
                        reward += 1
                    else:
                        reward -= 2
                else: # in front of paddle
                    reward += 2
        else:
            # print(f"hey the ball is being still{random.randint(0, 9)}")
            pass # no points for losing

        # successful bounce!
        if (data['ball_x'] < 580 + 50 and
            data['ball_x'] + 15 > 580 and
            data['ball_y'] < data['paddle_y'] + 100 and
            data['ball_y'] + 15 > data['paddle_y']):
            reward += 20
            print(f"BOUNCED!!{random.randint(0, 9)}")

        print(f"Reward:\t{reward}")

        # Store previous experience and train step if previous frame exists
        if last_state is not None:
            agent.store_transition(last_state, last_action, reward, current_state, done)
            agent.train_step()

        # Choose action for current state
        action_idx = agent.get_action(current_state_tensor, difficulty=DIFFICULTY)
        chosen_action_str = agent.actions[action_idx]

        # Update tracking
        last_state = None if done else current_state
        last_action = action_idx

        # Send action response back to Ruby
        sock.sendto(chosen_action_str.encode('utf-8'), addr)

    except KeyboardInterrupt:
        print("\nStopping PyTorch AI Server...")
        # Save the neural network weights to a file
        # TODO: If you'd like to save this, you can uncomment these two lines
        torch.save(agent.model.state_dict(), "pong_ai.pth") 
        print("Model weights successfully saved to 'pong_ai.pth'.")
        break
    except Exception as e:
        print(f"Error: {e}")