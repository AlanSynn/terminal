# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/alansynn/.local/share/nvim/plugged/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/Users/alansynn/.local/share/nvim/plugged/fzf/bin"
fi

source <(fzf --zsh)
