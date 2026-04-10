# AVR Elevator Simulator

A simulated multi-floor elevator system built on the ATmega2560 microcontroller, developed as the final project for DESN2000 (Engineering Design and Professional Practice) at UNSW Sydney, in collaboration with Zhongtai Zhang, Yicong Chen, and Yuanxu Sun.

## Overview

The system implements elevator control logic entirely in AVR assembly, accepting floor requests via a keypad and managing floor transitions, door sequencing, and emergency handling through direct hardware register manipulation — no operating system or HAL layer.

## System Design

**Input handling**
- 4x4 matrix keypad scanned via GPIO polling — digits 0–9 select target floors, `*` triggers emergency return
- Push button for manual door close while stationary

**Control logic**
- Floor sequencing and direction logic written in AVR assembly
- Timer-driven automatic door open/close with configurable dwell time
- Emergency protocol on `*` input: cancels queued requests, returns to ground floor, holds doors open

**Output peripherals**
- LED bank reflects current floor and transition state
- LCD displays current floor, target floor, and emergency status messages
- DC motor simulates door open/close mechanism, driven via PWM on PE4

## Hardware

- ATmega2560 development board
- 4x4 matrix keypad
- 16x2 LCD display
- LED array
- DC motor with driver circuit
- Push button

## Tools

- Microchip Studio (AVR assembly, flashing)
- AVRDUDE

## Project Structure

```text
elevator-simulator/
├── docs/
│   ├── dev-guide.md
│   ├── user-guide.md
│   └── extend code/
├── src/
│   └── main.s
└── README.md
```
