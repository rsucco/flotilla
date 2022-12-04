# Flotilla
Turn-based naval strategy game inspired by Battleship and XCOM. This is still very much a work in progress, and might end up proving overly ambitious, but I'm mostly doing this project as a way to get more familiar with Godot.

Basic gameplay is similar to Battleship, with some exceptions:
- Rather than a 10x10 rectangular grid, each player places their ships on a 15x15 hexagonal grid. Ships can be placed diagonally.
- Rather than starting with one of each ship, each player is alloted a certain amount of points to purchase ships, and can choose their own fleet composition.
- Some tiles are island tiles where ships are not allowed to go. Coastal batteries can be placed on these tiles.
- Every ship is allowed to fire at least once per turn.
- Every ship is allowed to move at least one tile or rotate at least 60° per turn.
- Most ships have a special ability that can be used after a cooldown period.
- Most ships have a passive ability that improves their effectiveness.
- Some ships have drawbacks that reduce their effectiveness under specific conditions.

### Ship Classes
##### Coastal Battery
- Weapon: Big Guns
- Size: 1
- Special Ability: None
- Passive Ability: Must be hit five times to destroy
- Drawbacks: Can only be placed on island tiles, reveals itself when it fires, cannot move

##### Corvette
- Weapon: Deck Gun
- Size: 2
- Special Ability: None
- Passive Ability: Plus 50% move speed if starting turn near an island tile
- Drawbacks: Has a 75% chance of sinking if hit in either hex

##### Destroyer
- Weapon: Anti-Ship Missiles
- Size: 3
- Special Ability: (ASW Strike - 4 turns) Select a hex on opponent's board; if the hex or any of its direct neighbors contacts an enemy submarine, sink it instantly (does not affect ships)
- Secondary Ability: (Lay Mine - 5 turns) Select a hex on opponent's board to place a mine; if any ships move over that tile, they will take a hit in a random hex
- Passive Ability: None
- Drawbacks: None

##### Submarine
- Weapon: Torpedo
- Size: 3
- Special Ability: (Nuclear Strike - 10 turns) Select a hex on opponent's board; instantly sinks any unit it hits directly and damages all hexes within two hexes of central hex
- Secondary Ability: (Sonar Pulse - 1 turn) Select a hex on opponent's board; reveals ships and submarines on that hex and its direct neighbors and also reveals the location of the submarine
- Passive Ability: Can only be hit by surface units on center hex
- Drawbacks: Sinks when any hex is hit by a mine, ASW strike, or another sub, sinks instantly when hit in center hex by surface unit, cannot shoot at island tiles except with Nuclear Strike

##### Cruiser
- Weapon: Anti-Ship Missiles
- Size: 3
- Special Ability: (EW Strike - 6 turns) Select a hex on opponent's board; prevents all units within two hexes of central hex from firing next turn and either resets or adds five to their special ability cooldowns, whichever is less
- Passive Ability: Has a 50% chance of intercepting incoming attacks from destroyers, cruisers, and aircraft carriers on hexes within two hexes of itself, has a 25% chance of intercepting incoming Nuclear Strike
- Drawbacks: None

##### Supply Tender
- Weapon: None
- Size: 3
- Special Ability: (UNREP - 6 turns) Completely heal an adjacent ship
- Passive Ability: If damaged, heals one hex every ten turns
- Drawbacks: Loses 50% move speed when damaged

##### Battleship
- Weapon: Big Guns
- Size: 4
- Special Ability: (Salvo - 7 turns) Shoot one central hex and damage whatever it contains as well as all of its immediate neighbors; if central hex is a damaged hex, sink the enemy ship instantly
- Passive Ability: Armor grants 25% chance of any hit against it not counting
- Drawbacks: None

##### Aircraft Carrier
- Weapon: F-35
- Size: 5
- Special Ability: (Recon Flight - 4 turns) Select three connecting hexes on opponent's board; reveals hexes and all their immediate neighbors
- Passive Ability: Can use two attacks in one turn instead of moving
- Drawbacks: If at least two hexes are damaged, can only use one attack move per turn

### Credits
- Graphics: [Antony Christian Sumakud](https://opengameart.org/content/sea-warfare-set-ships-and-more)
