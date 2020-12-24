#!/usr/bin/env sh

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar1 and bar2
MAIN_MONITOR =$(xrandr --query | grep " connected" | grep "primary" | cut -d" " -f1)
if type "xrandr"; then
    MONITOR=$MAIN_MONITOR polybar --reload main -c ~/.config/polybar/config.ini &
    MONITOR=$MAIN_MONITOR polybar --reload bottom -c ~/.config/polybar/config.ini &
else
  echo 'else'
  polybar main -c ~/.config/polybar/config.ini &
  polybar bottom -c ~/.config/polybar/config.ini &
fi

echo "Bars launched..."
