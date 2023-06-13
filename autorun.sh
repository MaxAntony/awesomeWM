#!/bin/sh

function run {
    if ! pgrep $1 > /dev/null ;
    then
        $@&
    fi
}

run nitrogen --restore

run /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
# run picom -b 

setxkbmap -layout "us,es" -option "grp:alt_shift_toggle"

