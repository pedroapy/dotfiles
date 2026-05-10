#!/usr/bin/env bash
# Check for pacman + AUR updates
OFFICIAL=$(checkupdates 2>/dev/null | wc -l)
AUR=0
if command -v yay &>/dev/null; then
    AUR=$(yay -Qua 2>/dev/null | wc -l)
fi

TOTAL=$((OFFICIAL + AUR))

if [ "$TOTAL" -eq 0 ]; then
    echo '{"text":"󰏗","tooltip":"System is up to date","class":"updated"}'
else
    PKGLIST=$(checkupdates 2>/dev/null)
    if [ "$AUR" -gt 0 ]; then
        AURLIST=$(yay -Qua 2>/dev/null)
        PKGLIST="${PKGLIST}\n--- AUR ---\n${AURLIST}"
    fi
    PKGLIST=$(echo -e "$PKGLIST" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "{\"text\":\"󰏗 ${TOTAL}\",\"tooltip\":\"${OFFICIAL} official, ${AUR} AUR\\n\\n${PKGLIST}\",\"class\":\"updates-available\"}"
fi
