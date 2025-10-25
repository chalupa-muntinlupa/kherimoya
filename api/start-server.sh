#!/bin/bash
set -e

# start server script

# of course, as this is in the api directory, it's some of the lowest level parts of Kherimoya. don't use this directly on the frontend

# this takes in one argument, which is the server name
# if there's no argument, it will prompt for a server name, so you can run this like a small cli tool

# project path, change this to your project path
# this is where everything happens, i'll probably make a json file with everything, like the project path and stuff
PROJECT_PATH="/home/chalupa/Developer/projects/kherimoya"
MARA_PATH="/home/chalupa/Developer/projects/kheremara/"
if [ ! -d "$PROJECT_PATH" ]; then
    echo "Project path does not exist: $PROJECT_PATH"
    exit 1
fi
cd $PROJECT_PATH

# venving
# shellcheck disable=SC1091
source "$MARA_PATH/maraenv/bin/activate"
# plugins require a DIFFERENT venv, which'll be implemented when Kheremara is somewhat done

# can't be on root!
if [[ $(id -u) = 0 ]]; then
    echo "Don't run on root!"
    exit 1
fi

# parse arguments
ARG_SERVER_NAME=""
if [[ $# -ge 1 ]]; then
  ARG_SERVER_NAME="$1"
fi

# function to read input with prompt, sanitize, and confirmation
# James Chambers made this! https://jamesachambers.com/ i just stole it
read_with_prompt() {
  local variable_name="$1"
  local prompt="$2"
  local default="${3-}"
  local value answer
  unset "$variable_name"
  while :; do
    read -r -p "$prompt: " value </dev/tty
    value="$(echo "$value" | xargs)" # trim whitespace
    value="$(echo "$value" | head -n1 | awk '{print $1;}' | tr -cd 'a-zA-Z0-9._-')"
    if [[ -z "$value" && -n "$default" ]]; then
      value="$default"
    fi
    echo -n "$prompt : $value -- accept (y/n)? "
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      declare -g "$variable_name"="$value"
      echo "$prompt: $value"
      break
    fi
    # else loop again
  done
}

if [[ -n "$ARG_SERVER_NAME" ]]; then
  # sanitize argument
  SERVER_NAME="$(echo "$ARG_SERVER_NAME" | xargs | head -n1 | awk '{print $1;}' | tr -cd 'a-zA-Z0-9._-')"
else
  # prompt for server name using read_with_prompt
  read_with_prompt SERVER_NAME "Enter a server name"
fi

# check if server exists in serverlist.json
SERVERLIST_FILE="$PROJECT_PATH/servers/serverlist.json"
if ! jq -e --arg name "$SERVER_NAME" '.[] | select(.name == $name)' "$SERVERLIST_FILE" >/dev/null; then
  if [[ -n "$ARG_SERVER_NAME" ]]; then
    echo "error: missing"
  else
    echo "there's no server with that name in the serverlist.json file"
  fi
  exit 1
fi

# assign all properties to variables and echo them
SERVER_JSON=$(jq -r --arg name "$SERVER_NAME" '.[] | select(.name == $name)' "$SERVERLIST_FILE")
NAME=$(echo "$SERVER_JSON" | jq -r '.name')
SERVER_PATH=$(echo "$SERVER_JSON" | jq -r '.server_path')
CONFIG_PATH=$(echo "$SERVER_JSON" | jq -r '.config_path')
EXTRA_PATH=$(echo "$SERVER_JSON" | jq -r '.extra_path')
SERVER_DIR_PATH=$(echo "$SERVER_JSON" | jq -r '.server_dir_path')
STATE_PATH=$(echo "$SERVER_JSON" | jq -r '.state_path // empty')

echo "name: $NAME"
echo "server_path: $SERVER_PATH"
echo "config_path: $CONFIG_PATH"
echo "extra_path: $EXTRA_PATH"
echo "server_dir_path: $SERVER_DIR_PATH"
echo "state_path: $STATE_PATH"

# directory into the server dir path
cd "$SERVER_DIR_PATH"

# check if server folder exists
if [ ! -d "$SERVER_PATH" ]; then
  if [[ -n "$ARG_SERVER_NAME" ]]; then
    echo "error: folderNotFound"
  else
    echo "there's no folder that actually exists for that server"
  fi
  exit 1
fi

# check if server is already running
if screen -list | grep -q "\.${SERVER_NAME}\s"; then
    if [[ $# -ge 1 ]]; then
        echo "error: alreadyRunning"
    else
        echo "Server '$SERVER_NAME' is already running! Use: screen -x $SERVER_NAME"
    fi
    exit 1
fi

# check if endstone is installed
if command -v endstone >/dev/null 2>&1; then
    # start server in a detached screen session
    screen -dmS "$SERVER_NAME" endstone -y -s "$SERVER_DIR_PATH"
    echo "started server in screen session $SERVER_NAME"
    sleep 2 # just in case
else
    if [[ $# -ge 1 ]]; then
        echo "error: noEndstone"
    else
        echo "Endstone isn't installed in $PROJECT_PATH/venvKherimoya/ !"
    fi
    exit 1
fi

echo finished