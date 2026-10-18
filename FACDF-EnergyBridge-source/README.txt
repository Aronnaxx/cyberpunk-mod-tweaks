FACDF Energy Bridge v1.0 - Flesh & Chrome <-> Dark Future
Built 2026-10-05 against Flesh And Chrome 1.30.0 and Dark Future 2.0.3 (game 2.31).

F&C is the master for energy, stamina and carry weight.
- Dark Future's Energy need mirrors F&C's energy pool every second (one number to manage;
  DF's tiredness effects, sounds and dialogue still trigger from it).
- DF's own energy drain, sleep recovery and caffeine boosts are ignored (F&C handles sleep and
  coffee is already an F&C drink). Glitter / Black Lace energy boosts from DF do nothing.
- Energy changes other mods make through DF (Hack The Corps, Jacked In, TheImmersiveWay, ...)
  are passed on to F&C (>= 1 point, not within 15 s of a time skip, not caffeine stacks).
- DF thirst raises F&C stamina costs (stage 2/3/4: x1.10/x1.20/x1.35 via FACExternal);
  DF's vanilla sprint/jump stamina cost flats are held at 0.
- r6/tweaks/zz_FACDarkFutureBridge neutralizes DF's 22 stamina / stamina-regen / carry-capacity
  modifiers (energy, thirst, nerve, cigarettes, Mr Whitey, Glitter, reduced carry weight).
Install in Vortex as its own mod, load after Flesh And Chrome and Dark Future.
Compiles with and without Dark Future (DF code is behind @if(ModuleExists("DarkFuture.Needs"))).
