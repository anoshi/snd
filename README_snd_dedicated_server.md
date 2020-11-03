# RWR Dedicated Search and Destroy (SnD) server on Ubuntu 20.04 LTS

This document guides you through setting up a dedicated [Search and Destroy](https://steamcommunity.com/sharedfiles/filedetails/?id=1869880394) server for Osumia Games' [Running with Rifles](https://store.steampowered.com/app/270150/RUNNING_WITH_RIFLES/).

## Requirements

* Steam account
* Purchased copy of RwR
* Ubuntu Linux Server with at least 2.4 GHz Dual Core CPU, 2 GB of RAM, and 2 GB storage
  * This build was completed on an AWS t2.medium EC2 instance using Ubuntu 20.04 LTS server AMI
* Server firewall / security group rules allowing the following inbound:

| Protocol | Port Range | Source | Description |
|----------|------------|--------|-------------|
| TCP | 1234 | 0.0.0.0/0 | RwR Server |
| UDP | 1234 | 0.0.0.0/0 | RwR Server |
| TCP | 27015 | 0.0.0.0/0 | SRCDS_Rcon |
| UDP | 27015 | 0.0.0.0/0 | Steam Gameplay Traffic |

_Note_: RwR Server default port is 1234. Alter this if your _start\_server_ command specifies a different port (at the time of writing, _start\_snd\_server.as_ script runs a dedicated server on port 1666. Will return to 1234 from 0.13.0)

## Configure server

The following commands should be run in order on your Ubuntu 20.04 server. You should be able to copy/paste the entirety of each block for rapid results.

**IMPORTANT**: You must provide a steam username for an account that has a purchased copy of [Running With Rifles](https://store.steampowered.com/app/270150/RUNNING_WITH_RIFLES/). The _steamcmd_ installation is removed after the initial config but is required to update the game content every time a new patch is released.

When done, your server will automatically run a dedicated Running With Rifles ([Search and Destroy](https://steamcommunity.com/sharedfiles/filedetails/?id=1869880394) mod) server as a service _rwr-snd_.

### As a user with `sudo su -` privileges

```sh
# enable 32-bit support and install required packages
sudo dpkg --add-architecture i386
sudo apt -y update
sudo apt -y install tmux lib32gcc1 libx11-6:i386 libxext6:i386 lib32z1 libstdc++6:i386 libgpg-error0:i386
```

```sh
# upgrade all installed packages
sudo apt -y upgrade
# create a user 'rwradmin' to run the dedicated game server
sudo useradd -U -m -K PASS_MAX_DAYS=-1 -c 'RwR server admin' -s /bin/bash rwradmin
# switch user to rwradmin
sudo su - rwradmin
```

### As the _rwradmin_ user

```sh
# YOU MUST enter your steam username when prompted, here
read -p "Provide your steam username: " STEAM_USER
# get steamcmd linux client
curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
# manual login once to cache user/pass credentials and steamguard check (if configured)
./steamcmd.sh +login $STEAM_USER +quit
```

```sh
# downloader/updater for RWR
./steamcmd.sh +login $STEAM_USER +force_install_dir ./rwr_gameserver +app_update 270150 validate +quit
```

```sh
# remove steamcmd and associated profile
for folder in .steam/ Steam/ linux*/ package/ public/ siteserverui/ ; do rm -rf ~/"$folder"; done;
for file in steamcmd.sh .bash_history; do rm -f ~/"$file"; done;
```

```sh
# link SnD workshop item ID to allow players to be prompted to download mod when joining server
echo 1869880394 > ~/rwr_gameserver/steam_workshop_items.txt
# Set value for server location
cat <<'EOF' > ~/rwr_gameserver/geoinfo.xml
    <geoinfo>
        <location value="Australia"/>
    </geoinfo>
EOF
# Send command on launch_server init to start SnD server
cat <<'EOF' > ~/rwr_gameserver/commands.xml
    <command_aliases>
        <alias name="init" command="start_script ../../snd/scripts/start_snd_server.as"/>
    </command_aliases>
EOF
# Get latest SnD build
cd ~/rwr_gameserver/media/packages
if [ ! -d snd ]; then
    git clone https://github.com/anoshi/snd.git;
else
    cd snd && git pull;
fi
# you were almost never here
history -c
# drop back to base user (who has sudo rights)
exit
```

### Returned to user with `sudo su -` privileges

```sh
# setup RwR dedicated server to run as a service on boot
cat <<'EOF' > ~/rwr-snd.service
    [Unit]
    Description=Running With Rifles Dedicated Server
    After=network.target

    [Service]
    Type=forking

    User=rwradmin
    Group=rwradmin

    WorkingDirectory=/home/rwradmin/rwr_gameserver/

    ExecStart=/usr/bin/tmux new -d -n 'RwR SnD Dedicated Server' -s 'snd' ./launch_server

    ExecStop=/usr/bin/tmux send -t 'snd' 'exit' ENTER

    Restart=on-failure
    RestartSec=30

    [Install]
    WantedBy=multi-user.target
EOF

# put the unit file into place with correct file perms and ownership
sudo cp rwr-snd.service /lib/systemd/system && sudo chmod 644 /lib/systemd/system/rwr-snd.service && sudo chown root:root /lib/systemd/system/rwr-snd.service && rm rwr-snd.service

# create link to source unit file in /lib... at /etc...
sudo ln -s /lib/systemd/system/rwr-snd.service /etc/systemd/system/rwr-snd.service
# and start 'rwr-snd' service on boot
sudo systemctl enable rwr-snd

# All configured, reboot to launch server
sudo reboot
```
