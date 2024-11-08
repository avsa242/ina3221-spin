{
----------------------------------------------------------------------------------------------------
    Filename:       core.con.ina3221.spin
    Description:    INA3221-specific constants
    Author:         Jesse Burt
    Started:        Nov 3, 2024
    Updated:        Nov 7, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ        = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR          = $40 << 1                  ' 7-bit format slave address
    T_POR               = 0                         ' startup time (usecs)

    DEVID_RESP          = $3220                     ' device ID expected response

' Register definitions
    CONFIG              = $00
    CONFIG_REGMASK      = $ffff
        RST             = 15
        CH1_EN          = 14
        CH2_EN          = 13
        CH3_EN          = 12
        AVG2            = 11
        AVG1            = 10
        AVG0            = 9
        VBUS_CT2        = 8
        VBUS_CT1        = 7
        VBUS_CT0        = 6
        VSH_CT2         = 5
        VSH_CT1         = 4
        VSH_CT0         = 3
        MODE3           = 2
        MODE2           = 1
        MODE1           = 0
        ' compounds of above multi-bit fields
        CH_EN           = 12
        AVG             = 9
        VBUS_CT         = 6
        VSH_CT          = 3
        MODE            = 0
        ' bitmasks: allow ( reg & x_BITS )
        CH_EN_BITS      = %111
        AVG_BITS        = %111
        VBUS_CT_BITS    = %111
        VSH_CT_BITS     = %111
        MODE_BITS       = %111
        ' bitmasks: clear ( reg & x_CLEAR )
        CH_EN_CLEAR     = (CH_EN_BITS << CH_EN) ^ CONFIG_REGMASK
        AVG_CLEAR       = (AVG_BITS << AVG) ^ CONFIG_REGMASK
        VBUS_CT_CLEAR   = (VBUS_CT_BITS << VBUS_CT) ^ CONFIG_REGMASK
        VSH_CT_CLEAR    = (VSH_CT_BITS << VSH_CT) ^ CONFIG_REGMASK
        MODE_CLEAR      = MODE_BITS ^ CONFIG_REGMASK
        SOFT_RESET      = (1 << RST)

    CH1_SHUNT_V         = $01
    CH1_BUS_V           = $02
    CH2_SHUNT_V         = $03
    CH2_BUS_V           = $04
    CH3_SHUNT_V         = $05
    CH3_BUS_V           = $06
    CH1_CRIT_ALT_LIM    = $07
    CH1_WARN_ALT_LIM    = $08
    CH2_CRIT_ALT_LIM    = $09
    CH2_WARN_ALT_LIM    = $0a
    CH3_CRIT_ALT_LIM    = $0b
    CH3_WARN_ALT_LIM    = $0c
    SHUNT_V_SUM         = $0d
    SHUNT_V_SUM_LIM     = $0e

    MASK_ENABLE         = $0f
    MASK_ENABLE_REGMASK = $7fff
        SCC1_3          = 12
        WEN             = 11
        CEN             = 10
        CF1_3           = 7
        SF              = 6
        WF1_3           = 3
        PVF             = 2
        TCF             = 1
        CVRF            = 0
        CONV_READY      = 1


    POWER_VALID_ULIM    = $10
    POWER_VALID_LLIM    = $11
    MFR_ID              = $fe
    DIE_ID              = $ff


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

