# Post-Install Guide

Pasos manuales a realizar después de ejecutar `./install.sh`.

## 1. Monitores

Detecta tus monitores y edita la configuración:

```bash
hyprctl monitors
vim ~/.config/hypr/monitors.conf
```

Formato: `monitor = name, resolution, position, scale`

Ejemplo dual monitor:
```
monitor = DP-1, 2560x1440@165, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
```

## 2. YubiKey — Autenticación U2F para sudo

Registra tu YubiKey:

```bash
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys
# Toca la YubiKey cuando parpadee
```

Para añadir una segunda llave de backup:

```bash
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys
```

Habilita U2F en sudo (requiere la YubiKey + contraseña):

```bash
sudo vim /etc/pam.d/sudo
```

Añade esta línea **después** de `auth include system-auth`:

```
auth required pam_u2f.so
```

Para login con YubiKey, edita `/etc/pam.d/system-auth` de la misma forma.

> **Importante**: Ten siempre una sesión root abierta mientras configuras PAM. Un error puede dejarte fuera del sistema.

## 3. Clipboard — Proteger contraseñas

cliphist guarda todo lo que copies, incluyendo passwords. 1Password limpia el clipboard automáticamente a los 30s, pero para otras apps:

```bash
# Limpiar historial manualmente
cliphist wipe

# Limitar entradas almacenadas (añadir a autostart.conf si quieres)
# wl-paste --type text --watch cliphist store --max-items 50
```

## 4. Wallpaper

Descarga el wallpaper de Bing del día:

```bash
~/bin/get-wallpaper.sh
```

Para que se ejecute al iniciar sesión, añade a `~/.config/hypr/autostart.conf`:

```
exec-once = ~/bin/get-wallpaper.sh
```

## 5. SSH Keys

Si usas 1Password como agente SSH:

```bash
# Añade a ~/.zsh/env o ~/.gitconfig_local:
# SSH_AUTH_SOCK=~/.1password/agent.sock
```

Si usas llaves locales:

```bash
ssh-keygen -t ed25519 -C "tu@email.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

## 6. Git — Configuración personal

Tu configuración personal está en `~/.gitconfig_local` (no se sube al repo). Si necesitas cambiarla:

```bash
vim ~/.gitconfig_local
```

Para firma de commits con SSH (recomendado):

```bash
cat >> ~/.gitconfig_local << 'EOF'
[gpg]
    format = ssh
[user]
    signingkey = ~/.ssh/id_ed25519.pub
[commit]
    gpgsign = true
EOF
```

## 7. Docker — Verificar acceso

Después de re-login (necesario por el grupo docker):

```bash
docker run --rm hello-world
```

Si prefieres Docker rootless (más seguro):

```bash
dockerd-rootless-setuptool.sh install
```

## 8. Firewall — Abrir puertos si es necesario

El firewall (ufw) está configurado con deny incoming por defecto. Si necesitas abrir puertos:

```bash
sudo ufw allow 8080/tcp    # Desarrollo web
sudo ufw allow 3000/tcp    # Node.js
sudo ufw status numbered    # Ver reglas
sudo ufw delete 2           # Borrar regla #2
```

## 9. Bluetooth — Emparejar dispositivos

```bash
bluetoothctl
# scan on
# pair XX:XX:XX:XX:XX:XX
# connect XX:XX:XX:XX:XX:XX
# trust XX:XX:XX:XX:XX:XX
```

## 10. Verificar hardware

```bash
fastfetch                    # Info del sistema
radeontop                    # Monitor GPU AMD
sensors                      # Temperaturas
btop                         # Monitor general
```
