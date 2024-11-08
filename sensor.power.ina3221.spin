{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.power.ina3221.spin
    Description:    Driver for the INA3221 3-channel shunt and bus voltage monitor
    Author:         Jesse Burt
    Started:        Nov 3, 2024
    Updated:        Nov 8, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
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

    long _shunt_res
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
    math:   "math.unsigned64"                   ' unsigned 64-bit math routines


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


PUB preset_adafruit_6062()
' Preset settings:
'   Adafruit #6062
    shunt_resistance(0_050)                     ' 50mOhm shunt resistance


PUB adc2amps(a): i
' Convert shunt voltage and resistance to current measurement
    ' i :=  v         / r
    return adc2shunt_volts(a) / _shunt_res


PUB adc2shunt_volts(a): v
' Convert shunt voltage ADC word to voltage
    return ( a * 40_000 )


PUB adc2volts(a): v
' Convert ADC word to voltage
'   a:          voltage ADC word
'   Returns:    voltage (micro-volts)
    return ( a * 8_000 )


PUB adc2watts(a)
' Convert ADC word to power
'   a:          power ADC word
'   Returns     power (micro-watts)
    return power_data(a)


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


PUB current_data(ch=1): a
' Read measured current data
'   ch:         ADC channel (1..3, default: 1)
'   Returns:    current data (=shunt voltage data)
    return shunt_voltage_data(ch)


PUB dev_id(): id
' Read device identification
    return readreg(core.DIE_ID)


PUB power_data(ch=1): p | sgn
' Read the measured power ADC word
    ' emulated: This chip lacks a power register, so calculate it from V*I

    p := voltage_data() * current_data()
    if ( p & $8000_0000 )                       ' get the sign
        sgn := -1
    else
        sgn := 1

    return math.multdiv(    voltage(), ...      '   s32 V
                            current(), ...      ' * s32 I
                            1_000_000) * sgn    ' = u64 P / 1_000_000


PUB power_data_rdy(): f
' Flag indicating a measurement is ready
'   Returns: TRUE (-1) or FALSE(0)
    return ( (readreg(core.MASK_ENABLE) & core.CONV_READY) == 1 )


PUB reset()
' Reset the device
    writereg(core.CONFIG, core.SOFT_RESET)


PUB samples_avg(s=-2): c
' Set number of samples used for averaging measurements
'   s:          1, 4, 16, 64, 128, 256, 512, 1024 (default: 1)
'   Returns:    current value if s is unspecified, or outside valid range
    c := readreg(core.CONFIG)
    case s
        1, 4, 16, 64, 128, 256, 512, 1024:
            s := lookdownz(s: 1, 4, 16, 64, 128, 256, 512, 1024) << core.AVG
            s := ((c & core.AVG_CLEAR) | s)
            writereg(core.CONFIG, s)
        other:
            c := (c >> core.AVG) & core.AVG_BITS
            return lookupz(c: 1, 4, 16, 64, 128, 256, 512, 1024)


PUB shunt_resistance(r=-2): c
' Set value of shunt resistor
'   r:          resistance (milliohms)
'   Returns:    current value if r is unspecified, or outside valid range
'   NOTE: This must be set correctly for current and power measurements to return valid data
    case r
        1..1_000:
            _shunt_res := r
        other:
            return _shunt_res


PUB shunt_voltage_data(ch=1): v
' Get shunt voltage data
'   ch:         ADC channel (1..3)
'   Returns:    shunt voltage (microvolts; 0..163_800)
    ' read shunt voltage ADC, extend sign, right-justify data
    return ( readreg(core.CH1_SHUNT_V * (1 #> ch <# 3)) << 16) ~> 19


PUB vbus_conv_time(r=-2): c
' Set bus voltage conversion time
'   r:          conversion time: 140, 204, 332, 588, 1100, 2116, 4156, 8244 (microseconds)
'   Returns:    current value if r is outside the allowed range
    c := readreg(core.CONFIG)
    case r
        140, 204, 332, 588, 1100, 2116, 4156, 8244:
            r := lookdownz(r: 140, 204, 332, 588, 1100, 2116, 4156, 8244)
            r := (c & core.VBUS_CT_CLEAR) | (r << core.VBUS_CT)
            writereg(core.CONFIG, r)
        other:
            c := ((c >> core.VBUS_CT) & core.VBUS_CT_BITS)
            return lookupz(c: 140, 204, 332, 588, 1100, 2116, 4156, 8244)


PUB voltage_data(ch=1): v
' Read the measured bus voltage ADC word
'   NOTE: If averaging is enabled, this will return the averaged value
    ' read bus voltage ADC, extend sign, right-justify data
    return ( readreg(core.CH1_BUS_V * (1 #> ch <# 3)) << 16) ~> 19


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

