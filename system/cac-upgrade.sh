#!/bin/sh

export LC_ALL=C
export LANG=C
export LANGUAGE=C

uid=
gid=
userid=clk

# need an interactive shell
case $- in
    *i*)
        ;;

    *)
        echo an interactive shell is needed
        exit 3
esac

# can only be run as root
id=`/usr/bin/id -u`
if [ "$id" -gt 0 ]
then
    echo can only be run as root
    exit 1
fi
echo running unattended system setup and uprgade as root

os=`uname | grep -i Linux`
if [ "$os" = "" ]; then
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

read -p 'provide ssh public key here: ' key
/bin/mkdir /home/clk/.ssh
/bin/chmod 700 /home/clk/.ssh
/bin/cat <<HERE > /home/clk/.ssh/authorized_keys
$key
HERE
/bin/chown -R clk:clk /home/clk/.ssh

echo installing git and zsh
/usr/bin/apt-get -y install git zsh
/usr/bin/chsh -s /bin/zsh clk

echo postpone making up /etc/sudoers
/bin/cat <<PP > /root/mksudoers
/bin/cat <<HERE >> /etc/sudoers
%clk   ALL=(ALL:ALL) NOPASSWD: ALL
HERE

/bin/rm -f /root/mksudoers
PP

echo preparing upgrade script
/bin/cat <<HERE > /tmp/upgrade.sh
/usr/bin/apt-get update
/usr/bin/apt-get -y upgrade
/usr/bin/apt-get -y dist-upgrade
/usr/bin/do-release-upgrade -y

/bin/cat <<PP >> /etc/rc.local

/bin/sh /root/mksudoers
PP

/sbin/reboot
HERE
/bin/chmod 700 /tmp/upgrade.sh

echo adding some sauce to /etc/screenrc to get a status line
/bin/cat <<HERE >> /etc/screenrc

# added by upgrade script
hardstatus alwayslastline
hardstatus string "%{= KW} %H [%\`] %{= Kw}|%{-} %-Lw%{= bW}%n%f %t%{-}%+Lw %=%C%a %Y-%M-%d"
HERE

echo disallowing root ssh login
/bin/sed 's/PermitRootLogin\s\+yes/PermitRootLogin no/' /etc/ssh/sshd_config > /tmp/sshd_config
/bin/mv /tmp/sshd_config /etc/ssh/sshd_config
/usr/sbin/service ssh reload

echo generating a screen rc to open up and run
/bin/cat <<HERE > /tmp/screen.rc
sessionname upgrade

screen top -c
screen /tmp/upgrade.sh
screen /bin/su clk -c /bin/sh -c 'cd /home/clk ; /bin/sh -c "\$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"'
HERE

# use screen here instead of tmux because the upgrade breaks tmux from resuming
echo entering screen to start system upgrade process
/usr/bin/screen -c /tmp/screen.rc
