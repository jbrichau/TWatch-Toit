import gpio
import spi
import color-tft show *
import pixel-display show *

get-display -> PixelDisplay:
  bus := spi.Bus
    --mosi=gpio.Pin 19
    --clock=gpio.Pin 18

  device := bus.device
    --cs=gpio.Pin 5
    --dc=gpio.Pin 27
    --frequency=32_000_000

  driver := ColorTft device 240 240
    --reset=null
    --backlight=gpio.Pin 15

  return PixelDisplay.true-color driver --inverted