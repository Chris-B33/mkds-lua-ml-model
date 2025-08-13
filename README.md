# MKDS-ML-Model

## Description
This is an attempt at creating a reinforcment learning model to play Mario Kart for the Nintendo DS. This project uses the Bizhawk emulator, its in-built Lua support and an external Python script to gain data from the game and train a model in real time on that data.

The Lua scripts were heavily adapted from <a href="https://github.com/SuuperW/BizHawk-Lua-Scripts/tree/main">these scripts</a> I found.

## TODO
#### Lua
- Change how memory is read so all addresses needed are referenced from a seperate file.

#### Python
- Open the ROM in the Bizhawk with the Lua scripts active.
- Write model to learn and dictate new moves.
- Load save states by file.

## Finished for now
#### Lua
- Read different stats such as speed and position from memory.
- Write stats to a file to be read by the Python scripts.
- Passed next checkpoint data through file.
- Normalised all data to be between -1 and 1 or 0 and 1.
- Set controls from a file written by the Python scripts.

#### Python
- Read current stats from a file written by the Lua scripts.
- Send new controls to a file to be read by the Lua scripts.

## Current Objective
Create basic RL model based on given stats.