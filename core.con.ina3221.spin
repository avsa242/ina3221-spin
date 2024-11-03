{
    --------------------------------------------
    Filename: core.con.ina3221.spin
    Author: Jesse Burt
    Description: INA3221-specific constants
    Copyright (c) 2024
    Started Nov 3, 2024
    Updated Nov 3, 2024
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ    = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR      = $40 << 1                  ' 7-bit format slave address
    T_POR           = 0                         ' startup time (usecs)

    DEVID_RESP      = $3220                     ' device ID expected response

' Register definitions
    CONFIG          = $00
    CH1_SHUNT_V     = $01
    CH1_BUS_V       = $02
    CH2_SHUNT_V     = $03
    CH2_BUS_V       = $04
    CH3_SHUNT_V     = $05
    CH3_BUS_V       = $06
    CH1_CRIT_ALT_LIM= $07
    CH1_WARN_ALT_LIM= $08
    CH2_CRIT_ALT_LIM= $09
    CH2_WARN_ALT_LIM= $0a
    CH3_CRIT_ALT_LIM= $0b
    CH3_WARN_ALT_LIM= $0c
    SHUNT_V_SUM     = $0d
    SHUNT_V_SUM_LIM = $0e
    MASK_ENABLE     = $0f
    POWER_VALID_ULIM= $10
    POWER_VALID_LLIM= $11
    MFR_ID          = $fe
    DIE_ID          = $ff


PUB null()
' This is not a top-level object

DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

