#!/bin/bash

# Add some config
sudo /bin/sh -c 'echo fastestmirror=true >> /etc/dnf/dnf.conf'
sudo /bin/sh -c 'echo deltarpm=true >> /etc/dnf/dnf.conf'

# Increase inode watcher for webpack and others
sudo /bin/sh -c 'echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf'
sudo /bin/sh -c 'sysctl -p'