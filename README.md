# Model Sniper <!-- omit from toc -->

Spawn models instantly from a list of known model paths without using the spawnmenu

## Table of Contents <!-- omit from toc -->
- [Model Sniper](#model-sniper)
  - [Features](#features)
  - [Rational](#rational)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)

## Model Sniper

![Model Sniper Preview](/media/modelsniper_preview.png)

This adds a spawner tool, "Model Sniper", which allows the player to spawn multiple props and ragdolls from a list of models. In addition, it also allows the player to add models from the world, either by clicking on the prop or selecting props in an area, and spawn them.

### Features

- Editable entry to specify a list of models to spawn models 
- Model picking, which either appends the selected entity's model to the list, or appends a collection of entities together
  - Also supports getting bonemerged models
  - Includes settings for visualizing or modifying the search volume
- Additional ability to filter out model path duplicates or spawn them together 
- TODO: Spawning patterns (rectangle, ellipse, or different shapes)

### Rational

If the model path is known, this tool circumvents an exhaustive lookup for the model to a simple click of the button. Previously, the user would either use the Spawnmenu's search function or walk through the Spawnmenu's game directories. If they discover a potential list of models in the directory or search result, the user would have evaluated the model icons by looking at them or by hovering their mouse to view the model path tooltip before they could spawn it. This step could repeat itelf for another model in a different directory.

Considering that the lookup step involve automatically searching through nests and nests of directories until the model is found, even when the list of models is already known, the tool's ability to "snipe" for the model(s) contrasts the lookup step by just the amount of time the tool saves in spawning the model. 

## Disclaimer

**This tool has been tested in singleplayer.** Although this tool may function in multiplayer, please expect bugs and report any that you observe in the issue tracker.

In its initial phase, this tool could be used maliciously due to its ability to spawn multiple models. I will read through some standards and code for other spawning tools to limit this tool's potential virulence. 

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.
