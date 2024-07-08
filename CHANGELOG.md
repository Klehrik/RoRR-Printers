### v1.0.0
* Initial release

### v1.0.1
* Tweaked spawning chances and amount
* Updated sprite
* Added sfx

### v1.0.2
* Updated icon.png
* Added short animation
* Change: Only prints vanilla items (as items from BreathingUnderwater did not spawn)
* Fix: Can no longer fire off infinite fireworks when interacting without a valid item

### v1.0.3
* Change: Can no longer print an item into itself
    * This is how it usually works in RoR2, but in Returns it is abusable with the Substandard Duplicator
    * This change will also prevent fireworks from being used freely in the same manner

### v1.0.4
* Fix: Printers can no longer be triggered using Explorer's Key

### v1.0.5
* Slightly tweaked floating item appearance
* 3 printers (white, green, red) will now always spawn in the Contact Light's cabin room

### v1.0.6
* Tweaked spawning chances again
    * 0 (40%), 1 (30%), 2 (20%), 3 (10%)
    * Avg.  1.2 -> 1.0
* Colored print prompt text with rarity color
* Can no longer print infinite copies using temporary items
    * I thought I had already covered this but I guess not
* Now prioritizes item scraps from Scrappers mod

### v1.0.7
* Added option to turn off hovering item names (in an ImGui window)
* Locked items can no longer spawn in printers

### v1.0.8
* Now synced in online multiplayer
* "Show printer item names" now defaults to false

### v1.0.9
* Printers no longer spawn when Command is active

### v1.0.10
* Fixed Command being checked in some situations as active when it isn't