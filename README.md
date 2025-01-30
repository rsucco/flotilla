# Flotilla
Turn-based naval strategy game inspired by Battleship and XCOM and written in Godot

Basic gameplay is similar to Battleship, with some exceptions:
- Rather than a 10x10 rectangular grid, each player places their ships on a 15x15 hexagonal grid. Ships can be placed diagonally.
- Rather than starting with one of each ship, each player is alloted a certain amount of points to purchase ships, and can choose their own fleet composition.
- Some tiles are island tiles where ships are not allowed to go. Coastal batteries can be placed on these tiles.
- Every ship is allowed to fire at least once per turn.
- Every ship is allowed to move at least one tile or rotate at least 60° per turn, unless more than 50% damaged.
- Most ships have a special ability that can be used after a cooldown period.
- Most ships have a passive ability that improves their effectiveness.
- Some ships have a second special ability to really mix things up.
- Some ships have drawbacks that reduce their effectiveness under specific conditions.

### Ship Classes
##### Coastal Battery
- Weapon: Big Guns
- Size: 1
- Points Cost: 2
- Special Ability: None
- Passive Ability: Must be hit five times to destroy
- Drawbacks: Can only be placed on island tiles, reveals itself when it fires, cannot move

##### Corvette
- Weapon: Deck Gun
- Size: 2
- Points Cost: 2
- Special Ability: None
- Passive Ability: Plus 50% move speed if starting turn near an island tile
- Drawbacks: Has a 75% chance of sinking if hit in either hex

##### Destroyer
- Weapon: Anti-Ship Missiles
- Size: 3
- Points Cost: 3
- Special Ability: (ASW Strike - 2 turns) Select a hex on opponent's board; if the hex or any of its direct neighbors contacts an enemy submarine, sink it instantly (does not affect ships)
- Secondary Ability: (Lay Mine - 3 turns) Select a hex on opponent's board to place a mine; if any ships move over that tile, they will take a hit in a random hex
- Passive Ability: None
- Drawbacks: None

##### Submarine
- Weapon: Torpedo
- Size: 3
- Points Cost: 3
- Special Ability: (Nuclear Strike - 6 turns) Select a hex on opponent's board; instantly sinks any unit it hits directly and damages all hexes within two hexes of central hex
- Secondary Ability: (Sonar Pulse - 1 turn) Select a hex on opponent's board; reveals ships and submarines on that hex and its direct neighbors and also reveals the location of the submarine
- Passive Ability: Can only be hit by surface units on center hex
- Drawbacks: Sinks when any hex is hit by a mine, ASW strike, or another sub, sinks instantly when hit in center hex by surface unit, cannot shoot at island tiles except with Nuclear Strike

##### Cruiser
- Weapon: Anti-Ship Missiles
- Size: 3
- Points Cost: 3
- Special Ability: (EW Strike - 3 turns) Select a hex on opponent's board; prevents all units within two hexes of central hex from firing next turn and either resets or adds five to their special ability cooldowns, whichever is less
- Passive Ability: Has a 50% chance of intercepting incoming attacks from destroyers, cruisers, and aircraft carriers on hexes within two hexes of itself, has a 25% chance of intercepting incoming Nuclear Strike
- Drawbacks: None

##### Supply Tender
- Weapon: None
- Size: 3
- Points Cost: 3
- Special Ability: (UNREP - 3 turns) Completely heal an adjacent ship
- Passive Ability: If damaged, heals one hex every ten turns
- Drawbacks: Loses 50% move speed when damaged

##### Battleship
- Weapon: Big Guns
- Size: 4
- Points Cost: 4
- Special Ability: (Salvo - 2 turns) Shoot one central hex and damage whatever it contains as well as all of its immediate neighbors; if central hex is a damaged hex, sink the enemy ship instantly
- Passive Ability: Armor grants 25% chance of any hit against it not counting
- Drawbacks: None

##### Aircraft Carrier
- Weapon: F-35
- Size: 5
- Points Cost: 5
- Special Ability: (Recon Flight - 2 turns) Reveals one row of hexes on opponent's board
- Passive Ability: Can use two attacks in one turn instead of moving
- Drawbacks: If at least two hexes are damaged, can only use one attack move per turn

##### Credits

###### Graphics
- [Antony Christian Sumakud](https://opengameart.org/content/sea-warfare-set-ships-and-more) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [Hugo Locurcio](https://github.com/Calinou/kenney-particle-pack) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [sbed](https://opengameart.org/content/95-game-icons) [(CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/deed.en)
- [Lorc](https://lorcblog.blogspot.com/) [(CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/deed.en)
- [Delapouite](https://delapouite.com/) [(CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/deed.en)
- [Japan Maritime Self-Defense Force](https://www.mod.go.jp/msdf/) [(CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.en)
- Ryan Succo

###### Sound
- [Iwan Gabovitch](https://opengameart.org/content/tiny-naval-battle-sounds-set) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [yd](https://opengameart.org/content/war-on-water-sndfx) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [Kenney](https://www.kenney.nl/) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [BananaMilkshake](https://freesound.org/s/632703/) [(CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.en)
- [SamsterBirdies](https://www.samsterbirdies.com/) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [Jason Lee](https://freesound.org/people/jasonlee3071/sounds/624588/) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [Benboncan](https://freesound.org/people/Benboncan/sounds/61304/?) [(CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.en)
- [Sheyvan](https://freesound.org/people/Sheyvan/packs/26842/) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [Thimras](https://opengameart.org/content/ship-sinking) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)
- [David Dumais](https://pixabay.com/sound-effects/large-underwater-explosion-190270/) [Pixabay Content License](https://pixabay.com/service/license-summary/)
- [DeevDaRabbit](https://freesound.org/people/DeevDaRabbit/sounds/636717/) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)

###### Music
- [Matthew Pablo](https://opengameart.org/content/blackmoor-tides-epic-pirate-battle-theme) [(CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/deed.en)
- [yd](https://opengameart.org/content/enemy-ship-approaching) [(CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/)

###### Programming
- Ryan Succo
