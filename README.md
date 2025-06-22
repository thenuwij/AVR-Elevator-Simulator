# AVR2560 Elevator Simulator

This project simulates a real-world elevator system using the Atmega2560 microcontroller. The elevator accepts user inputs through a keypad and provides output via an LCD, LEDs, and a rotating motor. It also includes core safety features such as an emergency return mechanism.

**Developed by:**  
Thenuja Wijesuriya, Zhongtai Zhang, Yicong Chen, Yuanxu Sun

## Features

- Floor selection using keypad (0–9)  
- Real-time floor updates via LEDs and LCD display  
- Automatic and manual door control using push-button and timer  
- Emergency protocol triggered by `*` key  
- Fully modularized and documented code

## Hardware Requirements

- Atmega2560 Board  
- USB Type-B to Type-A cable  
- Wired connections (motor, LED, LCD, push-button, keypad)  
- Computer with Windows OS or Virtual Machine

## Software Requirements

- Arduino IDE  
- Microchip Studio  
- AVRDUDE tool for flashing

## Documentation

- **User Guide:** Step-by-step setup and usage instructions  
- **Developer Guide:** Code structure, functions, and extension instructions (both in `docs/` folder)

## Key Functionalities

| Component    | Functionality                                      |
|--------------|----------------------------------------------------|
| Keypad       | Select floor (0–9), `*` for emergency return       |
| LEDs         | Display floor transitions and emergency status     |
| LCD          | Show current and next floor; emergency messages    |
| Motor        | Simulates door open/close sequence                 |
| Push Button  | Manually close the door while stationary           |

## Build & Upload Instructions

1. Connect the Atmega2560 board via USB  
2. Open the project using **Microchip Studio** or **Arduino IDE**  
3. Flash the code to the board using **AVRDUDE** or IDE's built-in tools  
4. Use the configuration and I/O mappings described in `docs/user-guide.md`

## Troubleshooting

- If motor, LCD, or LEDs are unresponsive: verify wiring (e.g., PE4 for motor)
- If keypad input is unrecognized: ensure the COM port and connections are correct
- If LCD is stuck in emergency mode: press `*` again to reset

## Project Structure

```text
elevator-simulator/
├── docs/
│   ├── dev-guide.md         # Developer documentation
│   ├── user-guide.md        # User documentation
│   ├── extend code/         # Additional extension assembly files
│   └── images/              # Circuit diagrams and screenshots
├── src/
│   └── main.s               # Main elevator control source file
├── .gitignore
└── README.md                # Project overview and setup instructions
