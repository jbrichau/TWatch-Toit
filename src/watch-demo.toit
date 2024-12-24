// Digital clock on a TFT display.
// This is a modified version of https://github.com/toitware/toit-color-tft/blob/main/examples/watch-demo.toit
// as a starter for this project

import color-tft show *
import font show *
import font-x11-adobe.sans-14-bold as sans-14
import gpio
import pixel-display show *
import pixel-display.element show *
import pixel-display.style show *
import pixel-display.true-color show *  // Provides WHITE and BLACK.
// Roboto is a package installed with
// toit pkg install toit-font-google-100dpi-roboto
// If this import fails you need to run `toit pkg fetch` in this directory.
import roboto.bold-36 as roboto-36-bold
import spi
import ntp
import esp32
import i2c
import .get-display

// Daylight savings rules in the EU as of 2023.
TIME-ZONE ::= "CET-1CEST,M3.5.0,M10.5.0/3"
// Daylight savings rules in the UK as of 2023.
// TIME-ZONE ::= "BST0GMT,M3.2.0/2:00:00,M11.1.0/2:00:00"
// Daylight savings rules for California as of 2023.
// TIME-ZONE ::= "PST8PDT,M3.2.0/2:00:00,M11.1.0/2:00:00"
// Find more time zone strings at https://support.cyberdata.net/portal/en/kb/articles/010d63c0cfce3676151e1f2d5442e311

DAYS ::= ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
MONTHS ::= ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

SANS := Font [sans-14.ASCII]
SANS-BIG := Font [roboto-36-bold.ASCII]

// Write the time and date.
// The time is hh:mm followed by the seconds in a smaller font.
// In order to avoid burn-in, the display changes position randomly about
// once every 10 seconds.  The date is written below the time.
main:
  set-time-from-net
  turn-on-backlight-power
  tft := get-display

  // Although SANS is not a fixed width font, the digits are all the same
  // width, so we can use zeros to measure the correct position of the blinking
  // colon.

  WIDTH-INDEX ::= 0
  HEIGHT-INDEX ::= 1
  h-m-extent := SANS-BIG.text-extent "00 00"
  h-m-width := h-m-extent[WIDTH-INDEX]
  h-m-height := h-m-extent[HEIGHT-INDEX]
  colon-offset := SANS-BIG.pixel-width "00"
  s-extent := SANS.text-extent "00"
  s-width := s-extent[WIDTH-INDEX]
  s-height := s-extent[HEIGHT-INDEX]

  // Since we don't have auto-layout yet, we use the font measurements
  // to place the elements in the box and determine the box size.
  time-y := h-m-height
  date-y := h-m-height + s-height + 6
  seconds-x := h-m-width + 5
  box-width := seconds-x + s-width
  box-height := date-y + s-height

  STYLE ::= Style
      --class-map = {
          "big": Style --color=0x32ff32 --font=SANS-BIG,
          "sans": Style --color=0xe6e632 --font=SANS,
      }
      --id-map = {
          "time": Style --x=0 --y=time-y,
          "colon": Style --x=colon-offset --y=time-y,
          "seconds": Style --x=seconds-x --y=time-y,
          "date": Style --x=0 --y=date-y
      }

  tft-width := max tft.width tft.height
  tft-height := min tft.width tft.height
  MIN-X ::= 0
  MAX-X ::= tft-width - box-width
  MIN-Y ::= 0
  MAX-Y ::= tft-height - box-height

  x := 20
  y := 20

  top := Div --x=0 --y=0 --w=tft-width --h=tft-height --background=0x000000 [
      Div --id="box" --x=x --y=y --w=box-width --h=box-height [
          Label --id="date" --classes=["sans"],
          Label --id="time" --classes=["big"],
          Label --id="colon" --classes=["big"],
          Label --id="seconds" --classes=["sans"],
      ]
  ]
  tft.add top
  tft.set-styles [STYLE]

  box := top.get-element-by-id "box"
  time := top.get-element-by-id "time"
  colon := top.get-element-by-id "colon"
  seconds := top.get-element-by-id "seconds"
  date := top.get-element-by-id "date"

  blink := true
  while true:
    // About once every 10 seconds we move the display to avoid burn-in.
    if (random 10) < 1:
      x += (random 3) - 1
      y += (random 3) - 1
      x = max MIN-X (min MAX-X x)
      y = max MIN-Y (min MAX-Y y)
      box.move-to x y
    local := Time.now.local
    date.text = "$(DAYS[local.weekday % 7]) $(MONTHS[local.month - 1]) $(local.day)"
    time.text = "$(%02d local.h) $(%02d local.m)"
    colon.text = blink ? ":" : ""
    blink = not blink
    seconds.text = "$(%02d local.s)"
    tft.draw
    sleep --ms=1000

set-time-from-net:
  set-timezone TIME-ZONE
  now := Time.now.utc
  if now.year < 1981:
    result ::= ntp.synchronize
    if result:
      esp32.adjust-real-time-clock result.adjustment
      print "Set time to $Time.now by adjusting $result.adjustment"
    else:
      print "ntp: synchronization request failed"

turn-on-backlight-power:
    bus := i2c.Bus
        --sda=gpio.Pin 21
        --scl=gpio.Pin 22

    device := bus.device 0x35
    power_output_control := device.registers.read-u8 0x12
    power_output_control = power_output_control | 0b100
    device.registers.write-u8 0x12 power_output_control