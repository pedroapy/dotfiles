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

> ⚠️ **Mantén una sesión root abierta** en otra TTY mientras configuras PAM. Un error te bloquea.

### Registrar llaves

Registra al menos **dos** YubiKeys (la principal y una de backup) — si solo registras una y la pierdes, te bloqueas del sistema.

```bash
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys     # primera llave (toca cuando parpadee)
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys  # segunda llave de backup
```

### Configurar PAM

Hay dos esquemas; elige según tu modelo de amenaza:

**Esquema A — `sufficient` (cómodo, password como fallback):**

YubiKey presente → sudo sin password. YubiKey ausente → password normal.

```bash
sudo vim /etc/pam.d/sudo
```

Añade **al principio del bloque `auth`** (antes de `auth include system-auth`):

```
auth sufficient pam_u2f.so cue
```

**Esquema B — `required` (alto, exige ambos factores):**

Tanto password **como** YubiKey son requeridos. Si pierdes todas las llaves (¡por eso registra dos!), te bloqueas — recuperación: editar `/etc/pam.d/sudo` desde un live USB o sesión root.

Añade **después** de `auth include system-auth`:

```
auth required pam_u2f.so cue
```

### Para login (TTY) con YubiKey

Edita `/etc/pam.d/system-local-login` con el mismo esquema que elegiste. **No edites `/etc/pam.d/system-auth`** directamente — afecta a todo el stack PAM y es más arriesgado.

### Verificar

```bash
sudo -K     # invalidar timestamp de sudo
sudo whoami # debería pedir YubiKey según esquema
```

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
