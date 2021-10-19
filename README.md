# Openframe Frame Controller

This is a fork and updated version of the [original Openframe Frame Conroller project](https://github.com/OpenframeProject/Openframe). This README file explains how to install and configure the Openframe frame controller.

## Overview

The Openframe frame controller is the software that runs on the frame itself (i.e. the RPi), acting as a process manager for starting, stopping, and transitioning between artworks. It communicates with an [Openframe API Server](https://github.com/mataebi/Openframe-APIServer) server via a REST API, and connects to a [global event system](https://github.com/OpenframeProject/Openframe-PubSubServer) allowing for realtime updates. The idea is to work towards a system which supports the basic goals of Openframe, guided by a handful of [pilot use cases](https://github.com/OpenframeProject/Openframe-APIServer/wiki/Pilot-Use-Cases).

The block diagram below represents the proposed architecture for the Openframe platform as of today

![alt tag](https://raw.githubusercontent.com/OpenframeProject/openframeproject.github.io/master/img/API%20Diagram%20v3.jpg)


## Install Node and NPM
The Openframe frame controller is based on nodejs and npm so these packages have to be installed first. There are two ways to do this which are explained below.

### Standard Installation
This is simple and straightforward using the Debian standard package manager. Run the following commands
```
sudo apt update && sudo apt install nodejs npm
```
This version of the frame controller software need at least version 12.x.x of nodejs but has also been tested with the current LTS version 14.x.x

### NVM based Installation
It might be helpful to use the node virtual machine (nmv) instead of a globallly installed version of node and npm. This is particularily useful to test a software with different vesions of the underlying node environment. When installing the Openframe client as described below this will automatically install nvm first so the following command does not need ot be executed explictly
```
curl -s https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
source ~/.bashrc
```
After installing nvm the system is now ready to install any version of node and npm needed. You may just use the major version number for installation and nvm will automatically figure out the latetst minor and patch version. nodejs 14 has proven to run well with the Openframe frame controller. So use the following commands to install it:
```
nvm install 14
```
To list the versions available under nvm use the following command:
```
nvm ls
        v7.10.1
        v8.17.0
        v9.11.2
       v12.22.6
->     v14.18.0
```
To activate one of the available version use the following command
```
nvm use 14
Now using node v14.18.0 (npm v6.14.15)
```

## Install the Openframe frame controller
Change to the current users home directory and clone the Openframe-FrameController repository from https://github.com/mataebi/Openframe-FrameController.git
```
cd
git clone https://github.com/mataebi/Openframe-FrameController.git
cd Openframe-FrameController
```

Do **not** run the install.sh script in the repository as it would try to install the frame controller software from npm.

Now setup the settings directory manually and copy the main configuration file (.ofrc) and the autostart script into it
```
mkdir -p ~/.openframe
cp -p .ofrc ~/.openframe/
cp ./scripts/autoboot.sh ~/.openframe/autoboot.sh
```

Now create the logfile that will be used by autoboot.sh and make it writable for the user that will run the frame controller software
```
sudo touch /var/log/openframe.log
sudo chown $(id -un):$(id -gn) /var/log/openframe.log
```

If you plan to setup and use your own Openframe server instead of the public system available at www.openframe.io you need to edit the frame controller configuration file (.ofrc) and adjust the URLs of the API and the web app server to match your services.
```
vi ~/.openframe/.ofrc
...
    "api_base": "https://oframe-api.example.com",
    "app_base": "https://oframe.example.com"
...
```

Now run `npm install` and `npm audit fix` to download and install all dependencies for the frame controller package and make sure at least part of the potential security risks in depnendencies are properly taken care of. This installation will also include the installtion of the four default extensions that will be downloaded and installed from npmjs.com.

Each of these extensions needs certain tools, libraries and executables that will also be installed during code initialization. So at each question asking `Do you want to continue? [Y/n]` just answer with `y`.
```
npm install
npm audit fix
```

To activate the `openframe` command and start the frame controller software, first create a link, then start the `openframe` software. Do not use `DEBUG=*` in front of the `openframe` command if you don't need additional information about the startup process:
```
sudo ln -s ~/Openframe-FrameController/bin/cli.js /usr/local/bin/openframe
source ~/.bashrc
DEBUG=* openframe
```
Once started, the first time the Openframe frame controller software will ask you the following questions:
```
...
? Enter your Openframe username: ppan
? Enter your Openframe password: ******
? Enter a name for this Frame: my-frame
? Do you want to boot openframe on startup?: (Y/n) n
```

A short while after answering the questions you should see the following messages:
```
[o]   Connected! You can now push artwork to this frame.
This frame should now appear as my-frame when you log into Openframe at https://oframe.example.com.
```
The easiest way to control the frame controller software is to install and activate the system service definition (of-framectrl.service) delivered as part of the software. After rebooting the frame controller software should start automatically. To install and activate the service execute the following commands:
```
sudo cp -p ~/Openframe-FrameController/scripts/of-framectrl.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable of-framectrl.service
sudo systemctl enable systemd-networkd-wait-online.service
sudo reboot
```
---

#### Modules

* `controller.js` - manages the actions around controlling the frame (changing artwork, updating settings, etc.)
* `process-manager.js` - manages starting and stopping processes for displaying artworks
* `extensions-manager.js` - manages installing and initializing extensions (aka plugins)
* `frame.js` - a wrapper for the Frame model, which gets persisted to
* `user.js` - a wrapper for the User model
* `pubsub.js` - creates and manages connection to global event system
* `rest.js` - creates and manages connection to REST API via Swagger.js
* `downloader.js` - utility for downloading files
* `config.js` - configuration options

Upon startup, the application will prompt you for your Openframe username and password, and a name for this frame. You can run this on a mac or linux machine (windows untested), though various artwork format extensions are likely to be developed with a specific target platform in mind.

For DEBUG output, set the DEBUG env var:

```bash
$ DEBUG=* npm start
```

### Configuration files

When you run `npm install`, the `install.sh` script will be executed. This script creates a hidden directory, `.openframe`, in your user home folder (/home/{username}/.openframe), and copies the default `.ofrc`configuration file there. The `.ofrc` file contains the server settings — by default this will point to the hosted API server at openframe.io, but if you're running a local server for development or are hosting your own API server you can update the settings in `.ofrc` accordingly.

After starting the application and answering the prompts, two additional files are created in the `.openframe` dir, `frame.json` which stores the frame state, and `user.json` which stores user data.

### Extensions

Extensions are npm packages which add functionality to the frame, either by adding support for a new artwork format (i.e. media type) or by adding other functionality.

For more info on extensions, see the [Openframe-Extension](https://github.com/OpenframeProject/Openframe-Extension) repo.
