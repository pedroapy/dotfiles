/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc

source ~/.zshrc
