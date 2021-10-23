#!/bin/bash
# Install the Openframe Framecontroller V0.5 directly from the corresponding repoitory at
# https://github.com/mataebi/Openframe-FrameController This script has been successfully
# tested on Raspberry 3 and 4 running Raspbian 10 (buster) and 11 (bullseye)

# Default Values
CFGDIR=$(ls -d ~/".openframe")

OFRCFILE="$CFGDIR/.ofrc"
OFRC='{ "network": { "api_base":"", "app_base":""}, "autoboot": ""}'

USERFILE="$CFGDIR/user.json"
USERDATA='{ "username": "", "password": "" }'

FRAMEFILE="$CFGDIR/frame.json"
FRAMEDATA='{ "name": "" }'

#----------------------------------------------------------------------------
 function get_frame_config {
#----------------------------------------------------------------------------
# Get the information needed to configure the name and credentials of this frame
  # Get existing credentials if any
  [ -r "$USERFILE" ] && USERDATA=$(cat "$USERFILE")

  ### Get Username
  USER=$(echo "$USERDATA" | jq ".username" 2>/dev/null | tr -d '"')
  [ "$USER" == "null" ] && USER=""
  while [ 1 ]; do
    read -p "Enter your Openframe username ($USER): " NUSER
    [[ ! "$NUSER" =~ ^[-a-zA-Z0-9_]*$ ]] && continue
    [ ! -z "$NUSER" ] && USER=$NUSER
    [ -z "$USER" ] && continue
    break
  done
  echo "USER: $USER"
  USERDATA=$(echo "$USERDATA" | jq ".username |= \"$USER\"")

  ### Get Password
  PASSWD=$(echo "$USERDATA" | jq ".password" 2>/dev/null | tr -d '"')
  [ $PASSWD == "null" ] && PASSWD=""
  while [ 1 ]; do
    local HIDDEN=""
    [ ! -z "$PASSWD" ] && HIDDEN="*****"
    read -p "Enter your Openframe password ($HIDDEN): " NPASSWD
    [ ! -z "$NPASSWD" ] && PASSWD="$NPASSWD"
    [ -z "$PASSWD" ] && continue
    break
  done
  echo "PASSWD: $PASSWD"
  USERDATA=$(echo "$USERDATA" | jq ".password |= \"$PASSWD\"")

  echo "$USERDATA"
  # echo "$USERDATA" > $USERFILE

  ### Get Framename
  [ -r $FRAMEFILE ] && FRAMEDATA=$(cat $FRAMEFILE)
  FRAME=$(echo "$FRAMEDATA" | jq ".name" 2>/dev/null | tr -d '"')
  [ $FRAME == "null" ] && FRAME=""
  while [ 1 ]; do
    read -p "Enter a name for this Frame ($FRAME): " NFRAME
    [[ ! "$NFRAME" =~ ^[-a-zA-Z0-9_]*$ ]] && continue
    [ ! -z "$NFRAME" ] && FRAME=$NFRAME
    break
  done
  echo "FRAME: $FRAME"
  FRAMEDATA=$(echo "$FRAMEDATA" | jq ".name |= \"$FRAME\"")

  echo "$FRAMEDATA"
  # echo "$FRAMEDATA" > $FRAEMFILE

  ### Ask for Autoboot
  [ -r $OFRCFILE ] && OFRC=$(cat $OFRCFILE)
  while [ 1 ]; do
    read -p "Do you want to boot openframe on startup (Y/n): " AUTOBOOT
    [[ ! "$AUTOBOOT" =~ (^[Yy][Ee]?[Ss]?$)|(^[Nn][Oo]?$)|(^$) ]] && continue
    [ -z $AUTOBOOT ] && AUTOBOOT="Y"
    break
  done

  if [[ $AUTOBOOT =~ ^[Yy] ]]; then
    AUTOBOOT="true"
  else
    AUTOBOOT="false"
  fi
  echo "AUTOBOOT: $AUTOBOOT"
  OFRC=$(echo "$OFRC" | jq ".autoboot |= \"$AUTOBOOT\"")

  # Get server URLs
  URLPAT='^https?://[-A-Za-z0-9]+\.[-A-Za-z0-9\.]+(:[0-9]+)?$'

  API_BASE_STD=$(echo "$OFRC" | jq .network.api_base | tr -d '"')
  until [[ $API_BASE =~ $URLPAT ]]; do
    read -p "URL to be used for API server ($API_BASE_STD)? " API_BASE
    [ -z $API_BASE ] && API_BASE=$API_BASE_STD
  done
  echo "API_BASE: $API_BASE"
  OFRC=$(echo "$OFRC" | jq ".network.api_base |= \"$API_BASE\"")

  APP_BASE_STD=$(echo "$OFRC" | jq .network.app_base | tr -d '"')
  until [[ $APP_BASE =~ $URLPAT ]]; do
    read -p "URL to be used for Web server ($APP_BASE_STD)? " APP_BASE
    [ -z $APP_BASE ] && APP_BASE=$APP_BASE_STD
  done
  echo "APP_BASE: $APP_BASE"
  OFRC=$(echo "$OFRC" | jq ".network.app_base |= \"$APP_BASE\"")

  echo "$OFRC"
  # echo "$OFRC" > $OFRCFILE
} # get_frame_config

#----------------------------------------------------------------------------
 function install_dpackage {
#----------------------------------------------------------------------------
# Check if a specific Debian package is installed already and install it
# if this is not the case
  local DPACKAGE=$1

  echo -e "\n***** Installing $DPACKAGE"
  dpkg -s $DPACKAGE > /dev/null 2>&1;
  if [ $? -gt 0 ]; then
    sudo apt update && sudo install -y $DPACKAGE
  else
    echo $DPACKAGE is already installed
  fi
} # install_dpackage

#----------------------------------------------------------------------------
 function install_nvm {
#----------------------------------------------------------------------------
# Make sure nvm is installed
  echo -e "\n***** Installing NVM"

  . ~/.nvm/nvm.sh
  local NVM_VERS=$(nvm --version 2>/dev/null)

  if [ ! -z "$NVM_VERS" ]; then
    echo "nvm is already installed"
    return
  fi
  
  cd ~/
  curl -s https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
  source ~/.bashrc
} # install_nvm

#----------------------------------------------------------------------------
 function install_node {
#----------------------------------------------------------------------------
# Make sure node and npm are installed under nvm
  local NODE_VERS=$1

  echo -e "\n***** Installing nodejs $NODE_VERS"
  nvm install $NODE_VERS
} # install_node

#----------------------------------------------------------------------------
 function install_framectrl {
#----------------------------------------------------------------------------
# Make sure node and npm are installed under nvm
  echo -e "\n***** Installing Openframe FrameController"
  cd ~/
  git clone https://github.com/mataebi/Openframe-FrameController.git
  cd Openframe-FrameController
  npm install
  npm audit fix
} # install_framectrl

#----------------------------------------------------------------------------
 function install_config {
#----------------------------------------------------------------------------
# Make sure the frame controller configuration is initialized if needed
  echo -e "\n***** Installing initial configuration"
  if [ ! -d  ~/.openframe/ ]; then
    echo "Creating configuration directory at ~/.openframe/"
    mkdir -p ~/.openframe
  fi

  if [ ! -r ~/.openframe/.ofrc ]; then
    echo "Initializing ~/.openframe/.ofrc"
    cp -p .ofrc ~/.openframe/
  fi
 
  # ~/.openframe/.env is used in the service script
  env | grep NVM_ > ~/.openframe/.env
  echo "PATH=$PATH" >> ~/.openframe/.env
} # install_config

#----------------------------------------------------------------------------
 function install_service {
#----------------------------------------------------------------------------
# Make sure the frame controller service is properly installed
  echo -e "\n***** Installing frame controller service"

  echo "Installing service at /lib/systemd/system/of-framectrl.service"
  sudo cp -p ~/Openframe-FrameController/scripts/of-framectrl.service /lib/systemd/system/
  sudo systemctl daemon-reload

  echo "Enabling services"
  sudo systemctl enable of-framectrl.service
  sudo systemctl enable systemd-networkd-wait-online.service
} # install_service

#----------------------------------------------------------------------------
 function install_command {
#----------------------------------------------------------------------------
# Make sure the frame controller command is properly installed
  echo -e '\n***** Installing "openframe" command'
  echo "Activating /usr/local/bin/openframe"
  [ ! -x /usr/local/bin/openframe ] && sudo ln -s ~/Openframe-FrameController/bin/cli.js /usr/local/bin/openframe
} # install_command

#----------------------------------------------------------------------------
 function install_extensions {
#----------------------------------------------------------------------------
# Make sure the default media extensions are installed
  echo -e "\n***** Installing Openframe default media extensions"

  echo "Installing Openframe-ImageViewer"
  openframe -i github:mataebi/Openframe-ImageViewer

  echo "Installing Openframe-VideoViewer"
  openframe -i github:mataebi/Openframe-VideoViewer

  echo "Installing Openframe-WebsiteViewer"
  openframe -i github:mataebi/Openframe-WebsiteViewer

  echo "Installing Openframe-glslViewer"
  openframe -i github:mataebi/Openframe-glslViewer
} # install_extensions

#----------------------------------------------------------------------------
# main
#----------------------------------------------------------------------------
  get_frame_config
  install_nvm
  install_node 14
  install_dpackage git
  install_dpackage jq
  install_framectrl
  install_config
  install_service
  install_command
  install_extensions

  echo -e '\nInstallation complete. Run "openframe" to configure and start the frame'
