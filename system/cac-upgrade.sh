#!/bin/sh

UID=
GID=
USERID=clk

# can only be run as root
uid=`/usr/bin/id -u`
if [ "$uid" -gt 0 ]
then
    echo can only be run as root
    exit 1
fi
echo running unattended system setup and uprgade as root

os=`uname -o | grep -i Linux`
if [[ "$os" == "" ]]; then
    # more precisely, Ubuntu
    echo this script works under Linux only
    exit 2
fi
echo OS is $os, good

echo changing root password
/usr/bin/passwd root

echo creating group and user account clk
/usr/sbin/groupadd -g 9487 clk
/usr/sbin/useradd -u 5566 -g 9487 -m clk

echo changing clk\'s password
/usr/bin/passwd clk

echo installing git and zsh
/usr/bin/apt-get -y install git zsh
/usr/bin/chsh -s /bin/zsh clk

echo installing oh-my-zsh
/bin/su clk -c /bin/sh -c "cd /home/clk ; /usr/bin/curl $(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh) ; exit"

read -p 'provide ssh public key here: ' key
/bin/mkdir /home/clk/.ssh
/bin/chmod 700 /home/clk/.ssh
/bin/cat <<HERE > /home/clk/.ssh/authorized_keys
$key
HERE

echo making up /etc/sudoers
/bin/cat <<HERE >> /etc/sudoers
%clk   ALL=(ALL:ALL) NOPASSWD: ALL
HERE

echo preparing upgrade script
/bin/cat <<HERE > /tmp/upgrade.sh
/usr/bin/apt-get update
/usr/bin/apt-get -y upgrade
/usr/bin/apt-get -y dist-upgrade
/usr/bin/do-release-upgrade -y
HERE

echo adding some sauce to /etc/screenrc to get a status line
/bin/cat <<HERE >> /etc/screenrc

# added by upgrade script
hardstatus alwayslastline
hardstatus string "%{= KW} %H [%\`] %{= Kw}|%{-} %-Lw%{= bW}%n%f %t%{-}%+Lw %=%C%a %Y-%M-%d"
HERE

echo generating a screen rc to open up and run
/bin/cat <<HERE > /tmp/screen.rc
sessionname upgrade

screen top -c
screen /tmp/upgrade.sh
HERE

# use screen here instead of tmux because the upgrade breaks tmux from resuming
echo entering screen to start system upgrade process
/usr/bin/screen -c /tmp/screen.rc