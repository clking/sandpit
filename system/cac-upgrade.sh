#!/bin/sh

export LC_ALL=C
export LANG=C
export LANGUAGE=C

uid=5566
gid=9487
userid=clk

# remove this manually
echo an interactive shell is needed and edit $0 manually
exit 3

# can only be run as root
id=`/usr/bin/id -u`
if [ "$id" -gt 0 ]
then
    echo can only be run as root
    exit 1
fi
echo running \(mostly\) unattended system setup and uprgade as root

os=`/bin/uname -a | /bin/grep -i Linux`
if [ -z $os ]; then
    # more precisely, Ubuntu
    echo this script works under Linux only
    exit 2
fi
echo OS is $os, looks good

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
#!/bin/sh

echo setting up post-setups in /etc/rc.local
/bin/cat <<PP >> /etc/rc.local

/bin/sh /root/mksudoers
PP

echo updating pkg list...
/usr/bin/apt-get update

echo upgrading packages....
/usr/bin/apt-get -y upgrade

echo upgrading kernel
/usr/bin/apt-get -y dist-upgrade

echo terminating screen
/usr/bin/killall top zsh
HERE
/bin/chmod 700 /tmp/upgrade.sh

echo adding some sauce to /etc/screenrc to get a status line
/bin/cat <<HERE >> /etc/screenrc

# added by upgrade script
hardstatus alwayslastline
hardstatus string "%{= KW} %H [%\`] %{= Kw}|%{-} %-Lw%{= bW}%n%f %t%{-}%+Lw %=%C%a %Y-%M-%d"
HERE

echo generating a screen rc to open up and run
/bin/cat <<HERE > /tmp/screen.rc
sessionname upgrade

screen top -c -d 1
screen /tmp/upgrade.sh
screen /bin/su clk -c /bin/sh -c 'cd /home/clk ; /bin/sh -c "\$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"'
HERE

# use screen here instead of tmux because the upgrade breaks tmux from resuming
echo entering screen to start system upgrade process
/usr/bin/screen -c /tmp/screen.rc

echo release upgrading
/usr/bin/do-release-upgrade -m server

echo disallowing root ssh login
/bin/sed 's/PermitRootLogin\s\+yes/PermitRootLogin no/' /etc/ssh/sshd_config > /tmp/sshd_config
/bin/mv /tmp/sshd_config /etc/ssh/sshd_config

echo all done and about to reboot, type[1m /sbin/reboot [mto do it
# /sbin/reboot
