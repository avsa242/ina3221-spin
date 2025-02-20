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
'       b2: CH0 (CH1 according to datasheet)
'       b1: CH1 (CH2 according to datasheet)
'       b0: CH2 (CH3 according to datasheet)
'   Returns:
'       current mask if m is unspecified or outside the valid range
    c := readreg(core.CONFIG)
    if ( (m => %000) and (m =< %111) )
        writereg(core.CONFIG, (c & core.CH_EN_CLEAR) | (m << core.CH_EN) )
    else
        return ( (c >> core.CH_EN) & core.CH_EN_BITS )


PUB current_data(ch=0): a
' Read measured current data
'   ch:         ADC channel (0..2, default: 0)
'   Returns:    current data (=shunt voltage data)
    ' this chip doesn't have a current monitoring reg, so we return the next closest thing to
    '   a 'raw' value: the shunt voltage data
    return shunt_voltage_data(ch)


PUB dev_id(): id
' Read device identification
    return readreg(core.DIE_ID)


PUB int_set_crit_thresh(thr, ch=0)
' Set current interrupt threshold (critical limit)
'   thr:        threshold in microamperes (default is maximum according to the shunt resistance)
'   ch:         channel to set threshold for (default is 0 if unspecified)
'   Returns:    none, or -1 if an invalid channel was specified
    if ( (ch < 0) or (ch > 2) )
        return -1

    writereg( (core.CH1_CRIT_ALT_LIM + (ch*2) ), ( (thr * _shunt_res) / 40_000) << 3 )


PUB int_set_vbus_hi_thresh(thr)
' Set bus voltage interrupt high threshold
'   thr:        threshold in microvolts
    writereg( core.POWER_VALID_ULIM, (thr / 8_000) << 3 )


PUB int_set_vbus_lo_thresh(thr)
' Set bus voltage interrupt low threshold
'   thr:        threshold in microvolts
    writereg( core.POWER_VALID_LLIM, (thr / 8_000) << 3 )


PUB int_set_vshunt_sum_thresh(thr)
' Set shunt voltage sum interrupt threshold (sum of all sum-enabled channels)
'   thr:        threshold in microamperes (signed)
    writereg(core.SHUNT_V_SUM_LIM, ((thr * _shunt_res) / 40_000) << 1 )


PUB int_set_warn_thresh(thr, ch=0)
' Set current interrupt threshold (warning limit)
'   thr:        threshold in microamperes (default is maximum according to the shunt resistance)
'   ch:         channel to set threshold for (default is 0 if unspecified)
'   Returns:    none, or -1 if an invalid channel was specified
    if ( (ch < 0) or (ch > 2) )
        return -1

    writereg( (core.CH1_WARN_ALT_LIM + (ch*2) ), ( (thr * _shunt_res) / 40_000) << 3 )


PUB int_vbus_hi_thresh(): t
' Get currenyly set bus voltage interrupt high threshold
    return ( readreg(core.POWER_VALID_ULIM) >> 3 ) * 8_000


PUB int_vbus_lo_thresh(): t
' Get currenyly set bus voltage interrupt low threshold
    return ( readreg(core.POWER_VALID_LLIM) >> 3 ) * 8_000


PUB int_vshunt_sum_thresh(): t
' Get currently set shunt voltage sum interrupt threshold (sum of all sum-enabled channels)
'   Returns:    threshold in microamperes (signed)
    return ( ( (readreg(core.SHUNT_V_SUM_LIM) << 16) ~> 17) * 40_000)


CON

    ' operating modes
    #0, POWERDN, VSHUNT_TRIGD, VBUS_TRIGD, VSHUNT_VBUS_TRIGD, POWERDN2, VSHUNT_CONT, VBUS_CONT, ...
    VSHUNT_VBUS_CONT

PUB opmode(m=-2): c
' Set operation mode
'   m:
'       POWERDN (0): Power-down/shutdown
'       VSHUNT_TRIGD (1): Shunt voltage, triggered
'       VBUS_TRIGD (2): Bus voltage, triggered
'       VSHUNT_VBUS_TRIGD (3): Shunt voltage and bus voltage, triggered
'       POWERDN2 (4): Power-down/shutdown
'       VSHUNT_CONT (5): Shunt voltage, continuous
'       VBUS_CONT (6): Bus voltage, continuous
'       VSHUNT_VBUS_CONT (7): Shunt voltage and bus voltage, continuous (default)
'   Returns:
'       current operating mode if m is unspecified or outside the valid range
    c := readreg(core.CONFIG)
    case m
        POWERDN, VSHUNT_TRIGD, VBUS_TRIGD, VSHUNT_VBUS_TRIGD, POWERDN2, VSHUNT_CONT, VBUS_CONT, ...
        VSHUNT_VBUS_CONT:
            m := lookdownz(m:   POWERDN, VSHUNT_TRIGD, VBUS_TRIGD, VSHUNT_VBUS_TRIGD, POWERDN2, ...
                                VSHUNT_CONT, VBUS_CONT, VSHUNT_VBUS_CONT)
            writereg(core.CONFIG, ((c & core.MODE_CLEAR) | m) )
        other:
            return (c & core.MODE_BITS)


PUB power_data(ch=0): p | sgn
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
'   Returns:    current value if s is unspecified or outside the valid range
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
'   Returns:    current value if r is unspecified or outside the valid range
'   NOTE: This must be set correctly for current and power measurements to return valid data
    case r
        1..1_000:
            _shunt_res := r
        other:
            return _shunt_res


PUB shunt_voltage_sum_data(): v
' Get summed shunt voltage data
'   Returns:    shunt voltage ADC word (s15)
'   NOTE: The value returned here depends on which channels are enabled with
'       shunt_voltage_sum_channels_ena()
    ' read shunt voltage ADC, extend sign, right-justify data
    return ( readreg(core.SHUNT_V_SUM) << 16 ) ~> 17


PUB shunt_voltage_data(ch=0): v
' Get shunt voltage data
'   ch:         ADC channel (0..2)
'   Returns:    shunt voltage ADC word (s12)
    ' read shunt voltage ADC, extend sign, right-justify data
    return ( readreg(core.CH1_SHUNT_V + ((0 #> ch <# 2)*2) ) << 16) ~> 19


PUB shunt_voltage_sum_channels_ena(m): c
' Set shunt voltage summing channels enabled mask
'   m:          ADC channel mask (b3..0: ch0, ch1, ch2)
'   Returns:    current mask if m is outside the allowed range
    c := readreg(core.MASK_ENABLE)
    if ( (m => %000) and (m =< %111) )
        m := (c & core.SCC1_3_CLEAR) | (m << core.SCC1_3)
        writereg(core.MASK_ENABLE, m)
    else
        return ((c >> core.SCC1_3) & core.SCC1_3_BITS)


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


PUB vshunt_conv_time(r=-2): c
' Set shunt voltage conversion time
'   r:          conversion time: 140, 204, 332, 588, 1100, 2116, 4156, 8244 (microseconds)
'   Returns:    current value if r is outside the allowed range
    c := readreg(core.CONFIG)
    case r
        140, 204, 332, 588, 1100, 2116, 4156, 8244:
            r := lookdownz(r: 140, 204, 332, 588, 1100, 2116, 4156, 8244)
            r := (c & core.VSH_CT_CLEAR) | (r << core.VSH_CT)
            writereg(core.CONFIG, r)
        other:
            c := ((c >> core.VSH_CT) & core.VSH_CT_BITS)
            return lookupz(c: 140, 204, 332, 588, 1100, 2116, 4156, 8244)


PUB voltage_data(ch=0): v
' Read the measured bus voltage ADC word
'   ch:         ADC channel (default: 0)
'   Returns:    bus voltage ADC word (s13)
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

