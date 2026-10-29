# Setup Guide — Ruby Pong AI Training

Follow these steps **in order** on Ubuntu / WSL (Windows Subsystem for Linux).

---

## Step 1: Install System Build Dependencies

Install all C build tools and X11/audio libraries SDL3 needs to compile:

```bash
sudo apt update
sudo apt install -y build-essential cmake git pkg-config \
  libx11-dev libxext-dev libxrandr-dev libxcursor-dev \
  libxfixes-dev libxi-dev libxtst-dev libxss-dev \
  libxkbcommon-dev libwayland-dev libpulse-dev \
  libasound2-dev libudev-dev libdbus-1-dev
```

---

## Step 2: Install rbenv (Ruby Version Manager)

```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
source ~/.bashrc
```

---

## Step 3: Install Ruby 4.0

```bash
rbenv install 4.0.0
rbenv global 4.0.0
ruby -v
```

You should see `ruby 4.0.0` or similar.

---

## Step 4: Install Ruby 2D Gem

```bash
gem install ruby2d
```

---

## Step 5: Build SDL3 (Ruby 2D's graphics backend)

Since Ubuntu's apt repos don't have SDL3 packages yet, let Ruby 2D build it from source:

```bash
ruby2d setup
```

> This will take a few minutes — it is compiling SDL3 from source.

---

## Step 6: Rebuild the Ruby 2D Native Extension

```bash
gem pristine ruby2d
```

---

## Step 7: Verify Everything Works

```bash
ruby -e "require 'ruby2d'; puts defined?(Button)"
```

If it prints `constant`, you are fully set up and ready to run the project.

---

## Step 8: Run the Project

```bash
ruby main_menu.rb
```

---

## Troubleshooting

| Error | Fix |
| :--- | :--- |
| `CMake Error: Couldn't find XTEST` | Re-run Step 1 (missing X11 dev packages) |
| `Error: Missing build tools: cmake` | `sudo apt install build-essential cmake git pkg-config` |
| `cannot load such file -- ruby2d` | Re-run Steps 4–6 |
| `rbenv: command not found` | Run `source ~/.bashrc` and try again |

