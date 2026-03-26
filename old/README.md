# Alis (SEGA Master System emulator)

This is a port to SDL from a very old graduation conclusion project mine.
The original version was written for Visual Studio and DirectX in 2002.

Alis is a SEGA Master System(SMS) emulator with a core engine written in
100% x86 assembly code, only the UI is written in C. All the assembly code
was converted from MASM to NASM format and DirectX to SDL API.

The name "Alis" is a tribute to the main character from my favorite game,
Phantasy Star.

## Features
You can enjoy these features while playing:

* **Save/Load** - Save and load game state any time;
* **Record/Play** - Record and play user input from keyboard or joystick;
* **CPU speed** - Change CPU speed between 12% and 800%;
* **Rewind** - Back to past!!! You can rewind your game until the last
thirty seconds;

## Keys

There are support for keyboard and joysticks.

* **F5-F8** - Save game in slots between 1 and 4;
* **F9-F12** - Load game from slots between 1 and 4;
* **SHIFT+[F5-F8]** - Record user input in slots between 1 and 4;
* **SHIFT+[F9-F12]** - Play user input from slots between 1 and 4;
* **MINUS(-)** - Decreases CPU speed;
* **EQUALS(=)** - Increases CPU speed;
* **BACKSPACE** - Rewind game played;
* **ESCAPE** - Reset;
* **SPACE** - Pause;
* **Z** - Joystick 1 button 1;
* **X** - Joystick 1 button 2;
* **UP,DOWN,LEFT,RIGHT** - Joystick 1 directions;
* **N** - Joystick 2 button 1;
* **M** - Joystick 2 button 2;
* **KEYPAD 1,2,3,5** - Joystick 2 directions;
