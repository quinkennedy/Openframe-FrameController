#!/bin/bash
# Install the Openframe Framecontroller V0.5 directly from the corresponding repoitory at
# https://github.com/mataebi/Openframe-FrameController This script has been successfully
# tested on Raspberry 3 and 4 running Raspbian 10 (buster) and 11 (bullseye)

# Default Values
HOMEDIR=$(ls -d ~)
CFGDIR="$HOMEDIR/.openframe"

OFRCFILE="$CFGDIR/.ofrc"
OFRCDATA='{ "network": { "api_base":"", "app_base":""}, "autoboot": ""}'

USERFILE="$CFGDIR/user.json"
USERDATA='{ "username": "", "password": "" }'

FRAMEFILE="$CFGDIR/frame.json"
FRAMEDATA='{ "name": "" }'

#----------------------------------------------------------------------------
 function get_frame_config {
#----------------------------------------------------------------------------
# Get the information needed to configure the name and credentials of this frame
  echo -e "\n***** Collecting configuration information"

  # Get existing credentials if any
  [ -r "$USERFILE" ] && USERDATA=$(cat "$USERFILE")

  ### Get Username
  USER=$(echo "$USERDATA" | jq ".username" 2>/dev/null | tr -d '"')
  [ -z "$USER" ] || [ "$USER" == "null" ] && USER=$(id -un)
  while [ 1 ]; do
    read -p "Enter your Openframe username ($USER): " NUSER
    [[ ! "$NUSER" =~ ^[-a-zA-Z0-9_]*$ ]] && continue
    [ ! -z "$NUSER" ] && USER=$NUSER
    [ -z "$USER" ] && continue
    break
  done
  USERDATA=$(echo "$USERDATA" | jq ".username |= \"$USER\"")

  ### Get Password
  PASSWD=$(echo "$USERDATA" | jq ".password" 2>/dev/null | tr -d '"')
  [ "$PASSWD" == "null" ] && PASSWD=""
  while [ 1 ]; do
    local HIDDEN=""
    [ ! -z "$PASSWD" ] && HIDDEN='*****'
    read -s -p "Enter your Openframe password ($HIDDEN): " NPASSWD
    echo
    [ ! -z "$NPASSWD" ] && PASSWD="$NPASSWD"
    [ -z "$PASSWD" ] && continue
    break
  done
  USERDATA=$(echo "$USERDATA" | jq ".password |= \"$PASSWD\"")

  ### Get Framename
  [ -r $FRAMEFILE ] && FRAMEDATA=$(cat $FRAMEFILE)
  FRAME=$(echo "$FRAMEDATA" | jq ".name" 2>/dev/null | tr -d '"')
  [ -z "$FRAME" ] || [ "$FRAME" == "null" ] && FRAME=$(hostname)
  while [ 1 ]; do
    read -p "Enter a name for this Frame ($FRAME): " NFRAME
    [[ ! "$NFRAME" =~ ^[-a-zA-Z0-9_]*$ ]] && continue
    [ ! -z "$NFRAME" ] && FRAME=$NFRAME
    break
  done
  FRAMEDATA=$(echo "$FRAMEDATA" | jq ".name |= \"$FRAME\"")

  ### Ask for Autoboot
  [ -r $OFRCFILE ] && OFRCDATA=$(cat $OFRCFILE)
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
  OFRCDATA=$(echo "$OFRCDATA" | jq ".autoboot |= \"$AUTOBOOT\"")

  # Get server URLs
  URLPAT='(^https?://[-A-Za-z0-9]+\.[-A-Za-z0-9\.]+(:[0-9]+)?$)|(^$)'

  API_BASE=$(echo "$OFRCDATA" | jq .network.api_base | tr -d '"')
  [ -z "$API_BASE" ] || [ "$API_BASE" == "null" ] && API_BASE="https://api.openframe.io"
  while [ 1 ]; do
    read -p "URL to be used for API server ($API_BASE)? " NAPI_BASE
    [[ ! "$NAPI_BASE" =~ $URLPAT ]] && continue
    [ ! -z "$NAPI_BASE" ] && API_BASE=$NAPI_BASE
    break
  done
  OFRCDATA=$(echo "$OFRCDATA" | jq ".network.api_base |= \"$API_BASE\"")

  APP_BASE=$(echo "$OFRCDATA" | jq .network.app_base | tr -d '"')
  [ -z "$APP_BASE" ] || [ "$APP_BASE" == "null" ] && APP_BASE="https://openframe.io"
  while [ 1 ]; do
    read -p "URL to be used for Web server ($APP_BASE)? " NAPP_BASE
    [[ ! "$NAPP_BASE" =~ $URLPAT ]] && continue
    [ ! -z "$NAPP_BASE" ] && APP_BASE=$NAPP_BASE
    break
  done
  OFRCDATA=$(echo "$OFRCDATA" | jq ".network.app_base |= \"$APP_BASE\"")
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
    sudo apt update && sudo apt install -y $DPACKAGE
  else
    echo $DPACKAGE is already installed
  fi
} # install_dpackage

#----------------------------------------------------------------------------
 function install_nvm {
#----------------------------------------------------------------------------
# Make sure nvm is installed
  echo -e "\n***** Installing NVM"

  . $HOMEDIR/.nvm/nvm.sh
  local NVM_VERS=$(nvm --version 2>/dev/null)

  if [ ! -z "$NVM_VERS" ]; then
    echo "nvm is already installed"
    return
  fi
  
  cd $HOMEDIR/
  curl -s https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash

  . $HOMEDIR/.nvm/nvm.sh
  local NVM_VERS=$(nvm --version 2>/dev/null)
} # install_nvm

#----------------------------------------------------------------------------
 function install_node {
#----------------------------------------------------------------------------
# Make sure node and npm are installed under nvm
  local NODE_VERS=$1

  echo -e "\n***** Installing nodejs $NODE_VERS"
  nvm install $NODE_VERS
  source $HOMEDIR/.bashrc
} # install_node

#----------------------------------------------------------------------------
 function install_framectrl {
#----------------------------------------------------------------------------
# Make sure node and npm are installed under nvm
  echo -e "\n***** Installing Openframe FrameController"
  cd $HOMEDIR/
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
  if [ ! -d  $CFGDIR/ ]; then
    echo "Creating configuration directory at $CFGDIR"
    mkdir -p $CFGDIR
  fi

  echo "Writing server information to $OFRCFILE"
  echo "$OFRCDATA" > $OFRCFILE

  echo "Writing user configuration to $USERFILE"
  echo "$USERDATA" > $USERFILE

  echo "Writing frame configuration to $FRAMEFILE"
  echo "$FRAMEDATA" > $FRAMEFILE
 
  # ~/.openframe/.env is used in the service script
  env | grep NVM_ > $CFGDIR/.env
  echo "PATH=$PATH" >> $CFGDIR/.env
} # install_config

#----------------------------------------------------------------------------
 function install_service {
#----------------------------------------------------------------------------
# Make sure the frame controller service is properly installed
  echo -e "\n***** Installing frame controller service"

  echo "Installing service at /lib/systemd/system/of-framectrl.service"
  local SERVICE_FILE=/usr/lib/systemd/system/of-framectrl.service
  sudo cp -p $HOMEDIR/Openframe-FrameController/scripts/of-framectrl.service $SERVICE_FILE
  sudo sed -i "s|<user>|$(id -un)|g" $SERVICE_FILE
  sudo sed -i "s|<configdir>|$CFGDIR|g" $SERVICE_FILE
  sudo systemctl daemon-reload

  if [ $AUTOBOOT == "true" ]; then
    echo "Enabling autostart of service"
    sudo systemctl enable of-framectrl.service
  else
    echo "Disabling autostart of service"
    sudo systemctl disable of-framectrl.service
  fi
  sudo systemctl enable systemd-networkd-wait-online.service
} # install_service

#----------------------------------------------------------------------------
 function install_command {
#----------------------------------------------------------------------------
# Make sure the frame controller command is properly installed
  echo -e '\n***** Installing "openframe" command'
  echo "Activating /usr/local/bin/openframe"
  [ ! -x /usr/local/bin/openframe ] && sudo ln -s $HOMEDIR/Openframe-FrameController/bin/cli.js /usr/local/bin/openframe
} # install_command

#----------------------------------------------------------------------------
 function install_extensions {
#----------------------------------------------------------------------------
# Make sure the default media extensions are installed
  echo -e "\n***** Installing Openframe default media extensions"

  echo -e "\n***** Installing Openframe-ImageViewer"
  npm install -g github:mataebi/Openframe-ImageViewer --save

  echo -e "\n***** Installing Openframe-VideoViewer"
  npm install -g github:mataebi/Openframe-VideoViewer --save

  echo -e "\n***** Installing Openframe-WebsiteViewer"
  npm install -g github:mataebi/Openframe-WebsiteViewer --save

  echo -e "\n***** Installing Openframe-glslViewer"
  npm install -g github:mataebi/Openframe-glslViewer --save
} # install_extensions

#----------------------------------------------------------------------------
# main
#----------------------------------------------------------------------------
  install_dpackage jq
  install_dpackage git
  get_frame_config
  install_nvm
  install_node 14
  install_framectrl
  install_config
  install_service
  install_command
  install_extensions

  echo
  echo '*************************************************************'
  echo '*                                                           *'
  echo '*  Installation complete. Execute "source ~/.bashrc" first  *'
  echo '*          then run "openframe" to start the frame          *'
  echo '*                                                           *'
  echo '*************************************************************'
  echo
