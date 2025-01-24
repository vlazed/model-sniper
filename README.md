# Model Sniper <!-- omit from toc -->

Spawn models instantly from a list of known model paths without using the spawnmenu

## Table of Contents <!-- omit from toc -->
- [Model Sniper](#model-sniper)
  - [Features](#features)
  - [Rational](#rational)
  - [Remarks](#remarks)
- [Disclaimer](#disclaimer)
- [Pull Requests](#pull-requests)

## Model Sniper

![Model Sniper Preview](/media/modelsniper_preview.png)

This adds a spawner tool, "Model Sniper", which allows the player to spawn multiple props and ragdolls from a list of models. In addition, it also allows the player to add models from the world, either by clicking on the prop or selecting props in an area, and spawn them.

### Features

- Editable entry to specify a list of models for spawning, and a model gallery which displays the icons of these models
  - Models from the gallery can also be spawned by clicking on them, just like the regular spawnmenu.
  - Right-clicking on a model icon brings up a menu to copy its path or view its folder if it has other models
- Model picking, which either appends the selected entity's model to the list, or appends a collection of entities together
  - Also supports getting bonemerged models
  - Includes settings for visualizing or modifying the search volume
- Filters to prevent from appending to list or spawning:
  - Duplicates
  - Ragdolls
  - Effect/Physics props
  - Players
- Spawning patterns (point, rectangle, circle)
  - Includes settings to preview patterns before spawning

### Rational

If the model path is known, this tool circumvents an exhaustive lookup for the model to a simple click of the button. Previously, the user would either use the Spawnmenu's search function or walk through the Spawnmenu's game directories. If they discover a potential list of models in the directory or search result, the user would have evaluated the model icons by looking at them or by hovering their mouse to view the model path tooltip before they could spawn it. This step could repeat itelf for another model in a different directory.

Considering that the lookup step involve automatically searching through nests and nests of directories until the model is found, even when the list of models is already known, the tool's ability to "snipe" for the model(s) contrasts the lookup step by just the amount of time the tool saves in spawning the model. 

### Remarks

To illustrate the capabilities and limitations of this tool, it is worth mentioning its similarities and differences to other existing tools.

- This tool's rational is similar to the Favorites addon (and spawnlists in general): it adds a tab to the spawnmenu, so users can spawn and categorize their favorite models without looking for them in the spawnmenu. This tool could be considered an alternative to the addon, where the models are saved in text files and categorized in this way. The novelty in this tool is the ability to spawn models directly given that we know the model path already, while the Favorites addon gives users the ability to find models given that they know how they categorized their models.
- This tool, unlike the Duplicator, picks the *models* of entities (not the entities themselves), either directly or in the search volume, and spawns them as one would when clicking on their icon in the spawnmenu. Hence, this tool should not be considered an alternative to the Duplicator tool. Rather, it may be used to gather multiple model paths at once.
  - To add to this, this tool does not (as of yet) give users the ability to save their model paths. I think this can be done by saving a text file of the specified models, although at this point, one could just use the Duplicator.
  - One subtle difference between this tool and the duplicator is that the Duplicator preserves bonemerged props on an entity, while this tool spawns them separately
- This tool, similar to the Random Array Tool, allows one to insert models to spawn by specifying their model path. However, this tool is not restricted to a single entry to spawn models, allowing one to choose which models to spawn by simply removing a line from the model list. This also enables a process of "transferring" lists of model paths between users.
- This tool, similar to the Random Array Tool and the Entity Group Spawner, can control the spawning pattern of the selected entities, constraining them to a point, a rectangle, or a circle. However, I opted to keep the spawning pattern deterministic, with no customization for skin or bodygroup randomness. These are just utilities to organize how the models are spawned.

## Disclaimer

**This tool has been tested in singleplayer.** Although this tool may function in multiplayer, please expect bugs and report any that you observe in the issue tracker.

In its initial phase, this tool could be used maliciously due to its ability to spawn multiple models. I will read through some standards and code for other spawning tools to limit this tool's potential virulence. 

## Pull Requests

When making a pull request, make sure to confine to the style seen throughout. Try to add types for new functions or data structures. I used the default [StyLua](https://github.com/JohnnyMorganz/StyLua) formatting style.
