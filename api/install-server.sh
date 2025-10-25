#!/bin/bash
set -e

# install server script

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

# can't be on root!
if [[ $(id -u) = 0 ]]; then
    echo "Don't run on root!"
    exit 1
fi

# fiahsfuashfihaihiafshfiashfiasfhaisfhasifhiasfihaihsfiahisfhaihsifasifh
SERVERS_DIR="$PROJECT_PATH/servers"
SERVERLIST_FILE="$SERVERS_DIR/serverlist.json"

# make sure servers directory exists
mkdir -p "$SERVERS_DIR"

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
  read_with_prompt SERVER_NAME "Enter a unique server name"
fi

SERVER_PATH="$SERVERS_DIR/$SERVER_NAME"
CONFIG_PATH="$SERVER_PATH/config"
EXTRA_PATH="$SERVER_PATH/extra"
SERVER_DIR_PATH="$SERVER_PATH/server"
STATE_PATH="$SERVER_PATH/state"

# check if server folder exists
if [ -d "$SERVER_PATH" ]; then
  if [[ -n "$ARG_SERVER_NAME" ]]; then
    echo "error: exists"
    exit 1
  else
    echo "there's another server with the same name, $SERVER_NAME"
    exit 1
  fi
fi

# create server folder structure
mkdir -p "$CONFIG_PATH" "$EXTRA_PATH" "$SERVER_DIR_PATH" "$STATE_PATH"

#cp "$LATEST_SYMLINK" "$SERVER_PATH/bedrock-server.zip" not needed after Endstone

# LEGACY: unzip server into server/
#unzip -q "$SERVER_PATH/bedrock-server.zip" -d "$SERVER_DIR_PATH"
#rm "$SERVER_PATH/bedrock-server.zip"
# Before Endstone, this was the way to install the server. Now, we use Endstone to handle *most* of this.

# endstone install server in the server & screen sesh, then a little after then , *because* endstone automatically starts it, then just "softstart" it by putting it in a screen and then stop it to generate everything
# if screen session exists
if screen -list | grep -q "\.${SERVER_NAME}\s"; then
    if [[ $# -ge 1 ]]; then
        echo "error: alreadyRunning"
    else
        echo "Server '$SERVER_NAME' is already running! (somehow, before creation) Use: screen -r $SERVER_NAME"
    fi
    exit 1
fi

cd "$SERVER_DIR_PATH" 
pwd
if command -v endstone >/dev/null 2>&1; then
    screen -dmS "$SERVER_NAME" endstone -y -s .
    sleep 5 # just in case

    # Wait for worlds/ folder to appear (timeout after 60 seconds)
    WORLD_DIR="$SERVER_DIR_PATH/worlds"
    echo "Waiting for worlds/ folder to appear in $SERVER_DIR_PATH..."
    WAIT_TIME=0
    echo "'Generating' the server. This might take a while, depending on your internet speed."
    while [ ! -d "$WORLD_DIR" ]; do # when a minecraft bedrock server is started, it generates the worlds/ folder. Endstone *automatically* does that after installing the server, so to detect once it is done, we just wait for the worlds/ folder as it's the easiest thing to do to know when it's done
      sleep 1
      WAIT_TIME=$((WAIT_TIME + 1))
      if [ $WAIT_TIME -eq 30 ]; then
        echo "Don't worry, still waiting for worlds/ folder to appear in $SERVER_DIR_PATH (30 seconds elapsed)..."
      fi
    done
    echo "done generating"
    sleep 3 # Just in case!!
    echo "trying to stop the screen session when we can"
    screen -Rd "$SERVER_NAME" -X stuff "stop $(printf '\r')" # after Endstone makes the server, it starts automatically (which is good but also a little bad for us, which is why we use this crappy worlds/ folder waiting), so we stop it
    sleep 3 # just in case
    echo "quitting screen session '$SERVER_NAME' now"
    screen -S "$SERVER_NAME" -X quit
else
    if [[ $# -ge 1 ]]; then
      echo "error: noEndstone"
    else
      echo "Endstone isn't installed in $PROJECT_PATH/venvKherimoya/ !"
    fi
    exit 1
fi

# [NOT IN EFFECT] find the bedrock_server binary in the server dir
#BEDROCK_BINARY="$(find "$SERVER_DIR_PATH" -maxdepth 2 -type f -name 'bedrock_server' | head -n1)"
#if [[ -z "$BEDROCK_BINARY" ]]; then
#  if [[ -n "$ARG_SERVER_NAME" ]]; then
#    echo "warn: missing-binary"
#    exit 1
#  else
#    echo "Could not find bedrock_server binary after extraction."
#    exit 1
#  fi # no binary means no binary location file, which is sometimes used by other scripts, thus, resulting in an error.
#fi # i sorta hate the binary location file because the json is just WAY better. i'll just keep it for like legacy things and whatever

#echo "$BEDROCK_BINARY" > "$BINARYLOCATION_PATH"

# copy config files from ./server/ to config/
CONFIG_SRC="$PROJECT_PATH/server"
for f in allowlist.json permissions.json server.properties; do
  if [ -f "$CONFIG_SRC/$f" ]; then
    cp "$CONFIG_SRC/$f" "$CONFIG_PATH/"
  fi
done # config/ is used as a backup for vanila configs like server.properties, and for extra config files (that aren't vanila!!).

# add server info to serverlist.json
if [ ! -f "$SERVERLIST_FILE" ]; then
    echo "[]" > "$SERVERLIST_FILE"
fi

# build server info object 
#--arg binarylocation_path "$BINARYLOCATION_PATH" \
SERVER_INFO=$(jq -n \
  --arg name "$SERVER_NAME" \
  --arg server_path "$SERVER_PATH" \
  --arg config_path "$CONFIG_PATH" \
  --arg extra_path "$EXTRA_PATH" \
  --arg server_dir_path "$SERVER_DIR_PATH" \
  --arg state_path "$STATE_PATH" \
  '{name: $name, server_path: $server_path, config_path: $config_path, extra_path: $extra_path, server_dir_path: $server_dir_path, state_path: $state_path}'
) # i love serverlist.json!!! but i don't know how to use it
#name - server name
#server_path - path to the server folder
#config_path - path to the ./config folder
#extra_path - path to the ./extra folder
#server_dir_path - path to the ./server folder (where the server binary is)
#state_path - path to the ./state folder (where the server state is stored, like if it's on and stuff)


# add server info if not present
if ! jq -e --arg name "$SERVER_NAME" '.[] | select(.name == $name)' "$SERVERLIST_FILE" >/dev/null; then
  TMP_JSON=$(mktemp)
  jq ". + [$SERVER_INFO]" "$SERVERLIST_FILE" > "$TMP_JSON" && mv "$TMP_JSON" "$SERVERLIST_FILE"
  if [[ -n "$ARG_SERVER_NAME" ]]; then
    echo "ok"
  else
    echo "Server '$SERVER_NAME' added to serverlist.json."
  fi
else
  if [[ -n "$ARG_SERVER_NAME" ]]; then
    echo "ok"
  else
    echo "Server '$SERVER_NAME' already in serverlist.json."
  fi
fi
# by the way, START USING THIS!!!!! i haven't seen anything use the json yet, and it's so good!!
# this is all done last because if the server setup fails, we don't want to add it to the serverlist.json and it won't brea kaytnhin

if [[ -z "$ARG_SERVER_NAME" ]]; then
  echo "Minecraft Bedrock server setup complete in $SERVER_PATH."
fi
echo finished