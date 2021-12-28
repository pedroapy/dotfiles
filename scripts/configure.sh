#!/bin/bash

# Increase inode watcher for webpack and others
sudo /bin/sh -c 'echo fs.inotify.max_user_watches=524288 | tee -a /etc/sysctl.conf'
sudo /bin/sh -c 'sysctl -p'
