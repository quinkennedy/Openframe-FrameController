#!/bin/bash

# If n has been pressed, don't start openframe
read -t 1 -n 1 key
    if [[ $key = n ]]
then
    echo "Skip booting Openframe."
else
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
        echo "logged in via SSH"
    else 
        # logged in locally (not via SSH)
      
        # hide the prompt:
        PS1=""
        # set the terminal text color to black
        setterm --foreground black --background black --cursor off --clear all
        # start up openframe as a background process
        DEBUG=* nohup openframe >/var/log/openframe.log 2>&1 &
    fi
fi
