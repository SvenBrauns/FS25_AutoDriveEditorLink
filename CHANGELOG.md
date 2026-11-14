# Version history

## 1.1.0

- Reload moves the vehicles' targets and parking positions to the renumbered markers, so deleting markers in the editor no longer mixes them up (`reload` request with `marker` entries)
- Vehicles: lists the vehicles and implements with their parking position (`vehicles` request) and sets parking positions (`park` request)

## 1.0.0

First release, for the AutoDrive FS25 Editor 2.0.0.

- Game picture: renders the map from above in tiles for the editor (`request.xml` type `pictures`). The HUD is hidden and the view distances are fixed during a capture; camera, HUD, view distances, weather and time are restored afterwards, also on cancel and error
- Reload: loads a network the editor saved into the running game (`request.xml` type `reload`), as AutoDrive's RoutesManager import does
- `status.xml` every second, so the editor knows the game is running and which map and savegame are loaded
