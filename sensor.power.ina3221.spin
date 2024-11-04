{
    --------------------------------------------
    Filename: sensor.power.ina3221.spin
    Author:
    Description:
    Copyright (c) 2024
    Started Nov 03, 2024
    Updated Nov 03, 2024
    See end of file for terms of use.
    --------------------------------------------
}

#include "sensor.power.common.spinh"

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 100_000
    I2C_ADDR    = 0

    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR|1


VAR

    byte _addr_bits


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef INA3221_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.ina3221.spin"             ' hw-specific constants
    time:   "time"                              ' basic timing functions


PUB null()
' This is not a top-level object


PUB start(): status
' Start the driver using default I/O settings
    return startx(SCL, SDA, I2C_FREQ, I2C_ADDR)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BITS): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   ADDR_BITS:  I2C alternate address bit, 0..3
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            _addr_bits := (ADDR_BITS << 1)
            if ( dev_id() == core.DEVID_RESP )  ' validate device 
                reset()
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()


PUB defaults()
' Set factory defaults
    reset()


PUB adc2amps(a)


PUB adc2volts(a): v
' Scale ADC word to voltage
'   a:          voltage ADC word
'   Returns:    voltage (micro-volts)
    return ( a * 8_000 )


PUB adc2watts(a)


PUB adc_chan_ena(m=-2): c
' Enable ADC channels
'   m:  bitmask of enabled channels
'       b2: CH1
'       b1: CH2
'       b0: CH3
'   Returns:
'       current mask, if m is outside the above range
    c := readreg(core.CONFIG)
    if ( (m => %000) and (m =< %111) )
        writereg(core.CONFIG, (c & core.CH_EN_CLEAR) | (m << core.CH_EN) )
    else
        return ( (c >> core.CH_EN) & core.CH_EN_BITS )


PUB current_data(): a


PUB dev_id(): id
' Read device identification
    return readreg(core.DIE_ID)


PUB reset()
' Reset the device
    writereg(core.CONFIG, core.SOFT_RESET)


PUB voltage_data(ch=1): v
' Read the measured bus voltage ADC word
'   NOTE: If averaging is enabled, this will return the averaged value
    return ( readreg(core.CH1_BUS_V * (1 #> ch <# 3)) << 15) ~> 18

PRI readreg(reg_nr, len=2): v | byte cmd_pkt[2]
' Read register value
'   reg_nr:     register
'   len:        length/number of bytes to read (default: 2)
'   Returns:    register value
    case reg_nr                                 ' validate register num
        $00..$11, $fe, $ff:
            cmd_pkt[0] := (SLAVE_WR | _addr_bits)
            cmd_pkt[1] := reg_nr
            v := 0
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start()
            i2c.wr_byte(SLAVE_RD | _addr_bits)
            i2c.rdblock_msbf(@v, len, i2c.NAK)
            i2c.stop()
        other:                                  ' invalid reg_nr
            return -1


PRI writereg(reg_nr, val, len=2) | byte cmd_pkt[2]
' Write register
'   reg_nr:     register to write
'   val:        value to write
'   len:        length/number of bytes to write (default: 2)
'   Returns:    none
    case reg_nr
        $00, $07..$0c, $0e..$11:
            cmd_pkt[0] := (SLAVE_WR | _addr_bits)
            cmd_pkt[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_msbf(@val, len)
            i2c.stop()
        other:
            return


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

