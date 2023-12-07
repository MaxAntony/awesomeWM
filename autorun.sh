#!/bin/sh

function run {
    if ! pgrep $1 > /dev/null ;
    then
        $@&
    fi
}

setxkbmap -layout "us,es" -option "grp:alt_shift_toggle"

# wallpaper
run nitrogen --restore

run /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
# run picom -b 
# Applications
run mattermost-desktop
run thunderbird
run ferdium

# find profile names in ~/config/google-chrome
# open chrome with 'pacami' profile and open youtube
# run google-chrome-stable --profile-directory="Default" https://youtube.com
# // TODO: Run next line only if there is no instances of chrome
# open chrome with 'empresa legal' profile and open youtube
# google-chrome-stable --profile-directory="Profile 5" https://youtube.com
# open chrome with 'IA' profile and open youtube
# google-chrome-stable --profile-directory="Profile 8" https://youtube.com
# open chrome with 'Fixa Digital' profile and open youtube
# google-chrome-stable --profile-directory="Profile 3" https://youtube.com

run firefox https://reddit.com
# // TODO: Run next line only if there is no instances of firefox
firefox https://dev.to



