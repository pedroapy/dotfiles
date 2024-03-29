sudo mkdir -pv /etc/systemd/system/getty@tty1.service.d/

sudo tee -a /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $USER %I $TERM
EOL
