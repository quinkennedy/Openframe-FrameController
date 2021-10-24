#!/bin/bash
# Do a complete Openframe-FrameController de-installation. Ask for each step
# unless the "-y" flag was passed

NOASK=$1

#----------------------------------------------------------------------------
 function ask {
#----------------------------------------------------------------------------
# Ask a yes or no question and set $ANSWER accordingly. Default answer is N
  if [ "$NOASK" == "-y" ]; then
    ANSWER="Y"
  else
    QUESTION=$1
    while [ 1 ]; do
      echo
      read -p "$QUESTION (y/N): " ANSWER
      [[ ! "$ANSWER" =~ (^[Yy][Ee]?[Ss]?$)|(^[Nn][Oo]?$)|(^$) ]] && continue
      [ -z $ANSWER ] && ANSWER="N"
      break
    done
    ANSWER=$(echo $ANSWER | cut -c1 | tr yn YN)
  fi
} # ask

#----------------------------------------------------------------------------
# main
#----------------------------------------------------------------------------
  cd ~/

  ask "Do you want to remove the Openframe-FrameController software?"
  if [ "$ANSWER" == "Y" ]; then
    echo "***** Removing Openframe-FrameController"
    rm -rf ~/Openframe-FrameController
  fi

  ask "Do you want to remove the frame configuration data?"
  if [ "$ANSWER" == "Y" ]; then
    echo "***** Removing openframe config"
    rm -rf ~/.openframe
  fi

  ask "Do you want to remove the nvm installation of user $(id -un)?"
  if [ "$ANSWER" == "Y" ]; then
    echo "***** Removing nvm installation"
    rm -rf ~/.nvm
    cat ~/.bashrc | grep -v "NVM_DIR" > /tmp/bashrc
    mv /tmp/bashrc ~/.bashrc
  fi

  ask "Do you want to remove the npm cache of user $(id -un)?"
  if [ "$ANSWER" == "Y" ]; then
    echo "***** Removing npm cache"
    rm -rf ~/.npm
  fi

  ask "Do you want to stop and uninstall the of-framectrl service on this frame"
  if [ "$ANSWER" == "Y" ]; then
    echo "***** Stopping and removing of-framectrl service"
    sudo service of-framectrl stop
    sudo systemctl disable of-framectrl
    sudo rm /lib/systemd/system/of-framectrl.service
  fi

  ask "Do you want to update the openframe install script of this machine"
  if [ "$ANSWER" == "Y" ]; then
    echo "***** Updating installation script"
    rm ~/install.sh
    curl -s https://raw.githubusercontent.com/mataebi/Openframe-FrameController/master/scripts/install.sh > ~/install.sh
    chmod a+x ~/install.sh
  fi
