#!/bin/sh
#
# The script executed when a Bourne shell is invoked as an interactive login
# shell.
# Contains commands to set up the Bourne shell environment.

main() {
    exportLocalPath
    exportPrograms
    exportXDGBaseDirectories
    exportVariables
    startWayland
}

exportLocalPath() {
    localPath="${HOME}/.local/bin"
    if isValidPath "${localPath}"; then
        export PATH="${PATH}:${localPath}"
    fi
}

exportPrograms() {
    export BROWSER="/usr/bin/firefox"
    export EDITOR="/usr/bin/nvim"
    export PAGER="/usr/bin/less"
    export TERM="/usr/bin/foot"
    export VISUAL="/usr/bin/nvim"
}

exportXDGBaseDirectories() {
    export XDG_CACHE_HOME="${HOME}/.cache"
    export XDG_CONFIG_DIRS="/etc/xdg"
    export XDG_CONFIG_HOME="${HOME}/.config"
    export XDG_DATA_DIRS="/usr/local/share:/usr/share"
    export XDG_DATA_HOME="${HOME}/.local/share"
    export XDG_STATE_HOME="${HOME}/.local/state"

    export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
    export HISTFILE="${XDG_STATE_HOME}/bash/history"
    export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"
}

exportVariables() {
    # Erase previous duplicates from the Bash history file.
    export HISTCONTROL="erasedups"
    # Don't truncate the Bash history file.
    export HISTFILESIZE=-1
    # Save all commands in the Bash history file without limit.
    export HISTSIZE=-1
    # Disable the less history file.
    export LESSHISTFILE="-"
}

startWayland() {
    dbus-run-session Hyprland
}

isValidPath() {
    directory="${1}"
    isDirectory "${directory}" && ! isDirectoryInPath "${directory}"
}

isDirectory() {
    directory="${1}"
    [ -d "${directory}" ]
}

isDirectoryInPath() {
    directory="${1}"
    echo "${PATH}" | grep --quiet "${directory}"
}

main
