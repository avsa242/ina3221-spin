# ina3221-spin 
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the INA3221 triple-channel power sensor.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* I2C connection at up to 400kHz
* Soft-reset
* Read bus voltage, shunt voltage, current, and power (per enabled channels), shunt voltage (summed) in ADC words or human-readable values (x1000000 scale integers)
* Set shunt resistance
* Set conversion time (Vbus, Vshunt)
* Set sample averaging mode
* Set operating mode: continuous or single-shot measurements, power down; any combination of bus and shunt voltage measurements
* Set interrupt thresholds (current)


## Requirements

P1/SPIN1:
* spin-standard-library
* `sensor.power.common.spinh` (provided by spin-standard-library)

P2/SPIN2:
* p2-spin-standard-library
* `sensor.power.common.spin2h` (provided by p2-spin-standard-library)


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | Build OK              |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Not yet implemented   |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | Not yet implemented   |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* doesn't support the HS I2C (2.44MHz) interface

