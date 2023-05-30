#!/bin/sh

function run {
    if ! pgrep $1 > /dev/null ;
    then
        $@&
    fi
}

setxkbmap -layout "us,es" -option "grp:alt_shift_toggle"

run nitrogen --restore
# run picom -b 
