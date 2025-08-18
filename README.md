# MKDS-ML-Model

## Description
This is an attempt at creating a reinforcment learning model to play Mario Kart for the Nintendo DS. This project uses the Bizhawk emulator, its in-built Lua support and an external Python script to read data from the games RAM and train a model in real time on that data. This is a DQN (Deep Q-Learning) model ran using PyTorch.
Lua scripts that read the emulators memory were largely adapted from <a href="https://github.com/SuuperW/BizHawk-Lua-Scripts/tree/main">these scripts</a>.

## Preview
<img src="assets/gifs/example.gif">

## Installation
### Directory
- Put this repo in the same directory as Bizhawk so it looks similar to:
<br>--BizHawk--
<br>¬> dll
<br>¬> Gameboy
<br>¬> gamedb
<br>¬> Lua
<br>¬> mkds-lua-ml-model
<br>¬> NDS
<br>¬> NES
<br>¬> overlay
<br>¬> Shaders
<br>-Emuhawk.exe

### Running the model
- Run main.py.
- Open ROM.
- Open the Lua console from Tools>Lua Console.
- Run src/emulator/main.lua.

## Current Objective
Tightening hyperparameters.