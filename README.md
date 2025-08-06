# MKDS-ML-Model

## Description
This is an attempt at creating a reinforcment learning model to play Mario Kart for the Nintendo DS. This project uses the Bizhawk emulator, its in-built Lua support and an external Python script to gain data from the game and train a model in real time on that data.

The Lua scripts were heavily adapted from <a href="https://tasvideos.org/GameResources/DS/MarioKartDS">this script</a> I found online.

## TODO
#### Lua
- Send the current frame to Python.
- Change how memory is read so you can set all addresses needed in a seperate file
- Potentially create a socket-based pipeline

#### Python
- Open the ROM in the Bizhawk with the Lua scripts active.
- Get the current frame either from Lua or directly with a library.
- Write model to learn and dictate new moves.

## Finished for now
#### Lua
- Read different stats such as speed and position from memory.
- Write controls and stats to a file to be read by the Python scripts.
- Read and set controls from a file written by the Python scripts.

#### Python
- Read current stats and contrls from a file written by the Lua scripts.
- Send new controls to a file to be read by the Lua scripts.

## Current Objective
Get frame info sent by Lua and received and displayed by Python