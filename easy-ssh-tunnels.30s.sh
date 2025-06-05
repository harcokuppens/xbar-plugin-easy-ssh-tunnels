#!/bin/bash
# <xbar.title>SSH tunnels with 2FA(OTP) support made easy</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Harco Kuppens</xbar.author>
# <xbar.author.github>harcokuppens</xbar.author.github>
# <xbar.desc>Easily create SSH tunnels automatically using password/keys and optionally an OTP secret stored in the MacOS keychain, or use interactive authentication dialogs to supply password or OTP code manually.</xbar.desc>
# <xbar.image></xbar.image>
# <xbar.dependencies>jq, gawk, oathtool, and expect</xbar.dependencies>
# <xbar.abouturl>https://github.com/harcokuppens/xbar-plugin-easy-ssh-tunnels</xbar.abouturl>

# Get the directory of the current plugin script
# This is crucial for portability, as xbar might execute from a different CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# add paths:
#  - bin/ folder of this plugin
#  - homebrew bin folder, because we use some homebrew utilities like gawk,oathtool
export PATH="$PATH:$SCRIPT_DIR/easy-ssh-tunnels/bin:/opt/homebrew/bin"

GET_TUNNEL_PID="ssh_tunnel_get_process_id"
# absolute paths of commands used in menu
TOGGLE_TUNNEL="$SCRIPT_DIR/easy-ssh-tunnels/bin/logged_toggle_tunnel"

#------------------------
# load config
#------------------------
# loads json configuration objects in bash arrays
#  - each json object has the port numbers as unique identifier
#  - there we take as key for arrays the port number
#  - for other object fields we define per field an a array:
#       TUNNEL_LABELS, TUNNEL_TYPE, TUNNEL_EXPECT_WRAPPERS, TUNNEL_COMMANDS

source "$SCRIPT_DIR/easy-ssh-tunnels/lib/load_tunnels_from_json.sh"

# Define the path to your JSON file and log file
TUNNELS_JSON_FILE="$SCRIPT_DIR/easy-ssh-tunnels/tunnels.json"
TUNNELS_LOGFILE="$SCRIPT_DIR/easy-ssh-tunnels/log.txt"

# Call the function to load the data
if ! load_tunnels_from_json "$TUNNELS_JSON_FILE"; then
    echo "Script terminated due to data loading error." >&2
    exit 1
fi

# ------------
#  get status of ssh tunnels
# ------------

# variable which is true if any tunnel is active
ACTIVE="false"
# array to store pid of active tunnels by port number
# This will be used to check if a tunnel is already running
number_of_active_tunnels=0
TUNNEL_ACTIVE=()
for PORT in "${!TUNNEL_COMMANDS[@]}"; do
    TUNNEL_PID=$("$GET_TUNNEL_PID" "$PORT")
    if [[ -n "$TUNNEL_PID" ]]; then
        # store $TUNNEL_PID for tunnels that are active"
        TUNNEL_ACTIVE["$PORT"]="$TUNNEL_PID"
        ACTIVE="true"
        # increment number_of_active_tunnels
        ((number_of_active_tunnels = number_of_active_tunnels + 1))
    fi
done

# ------------------

# Function to output menu items for each tunnel type
output_menu_items() {
    # Loop over the keys (PORT numbers) of the TUNNEL_COMMANDS array to display menu items in xbar
    TYPE="$1" # The type of tunnel (e.g., "Local Forwards", "Proxy Forwards")
    MENU_SPACE="\xe2\x80\x8a"
    for PORT in "${!TUNNEL_COMMANDS[@]}"; do
        # Check if the port matches the type of tunnel we are displaying
        if [[ "${TUNNEL_TYPE[$PORT]}" != "$TYPE" ]]; then
            continue # Skip this port if it doesn't match the type
        fi
        # Initialize variables for the tunnel command, label, and PID
        # For each port, retrieve its command and label
        TUNNEL_COMMAND="${TUNNEL_COMMANDS[$PORT]}"
        TUNNEL_LABEL="${TUNNEL_LABELS[$PORT]}"
        TUNNEL_PID="${TUNNEL_ACTIVE[$PORT]}"
        TUNNEL_EXPECT_WRAPPER="${TUNNEL_EXPECT_WRAPPERS[$PORT]}"

        if [[ -n "$TUNNEL_PID" ]]; then
            TUNNELICON="🟢"
            TUNNELINFO="(PID=$TUNNEL_PID)"
        else
            TUNNELICON="⚪"
            TUNNELINFO=""
        fi
        # output menu item
        #echo "$MENU_SPACE $TUNNELICON $PORT $TUNNEL_LABEL $TUNNELINFO | shell='$TOGGLE_TUNNEL' param1='$PORT' param2='$TUNNEL_COMMAND' param3='$TUNNEL_EXPECT_WRAPPER' terminal=false  "
        echo " $TUNNELICON $PORT $TUNNEL_LABEL $TUNNELINFO | shell='$TOGGLE_TUNNEL' param1='$PORT' param2='$TUNNEL_COMMAND' param3='$TUNNEL_EXPECT_WRAPPER' terminal=false trim=false "

        # note: no 'refresh=true' on menu, because TOGGLE_TUNNEL command must detach with nohup to keep its ssh process running,
        #       and therefore returns before tunnel setup is done. Instead the detached TOGGLE_TUNNEL command does call xbar_refresh,
        #       when tunnel is running.
        #echo "$MENU_SPACE $TUNNELICON $PORT $TUNNEL_LABEL $TUNNELINFO | shell='$SCRIPT_DIR/easy-ssh-tunnels/bin/toggle_tunnel' param1='$PORT' param2='$TUNNEL_COMMAND' param3='$TUNNEL_EXPECT_WRAPPER' terminal=false refresh=true "
    done
}

#------------------------
# superscript helpers
#------------------------

# Function to convert a single digit to its superscript character
# This function is not used directly below, but useful for understanding the mapping.
# It's more practical to use the full `to_superscript` function for multi-digit numbers.
get_superscript_digit() {
    local digit="$1"
    case "$digit" in
    0) echo "⁰" ;;
    1) echo "¹" ;;
    2) echo "²" ;;
    3) echo "³" ;;
    4) echo "⁴" ;;
    5) echo "⁵" ;;
    6) echo "⁶" ;;
    7) echo "⁷" ;;
    8) echo "⁸" ;;
    9) echo "⁹" ;;
    *) echo "$digit" ;; # Fallback for non-digit characters (though input should be digits)
    esac
}

# Function to convert an entire number string to its superscript equivalent
to_superscript() {
    local number_str="$1"
    local superscript_str=""
    local i

    # Iterate over each character (digit) in the input number string
    for ((i = 0; i < ${#number_str}; i++)); do
        local digit="${number_str:$i:1}" # Extract one character at a time
        case "$digit" in
        0) superscript_str+="⁰" ;;
        1) superscript_str+="¹" ;;
        2) superscript_str+="²" ;;
        3) superscript_str+="³" ;;
        4) superscript_str+="⁴" ;;
        5) superscript_str+="⁵" ;;
        6) superscript_str+="⁶" ;;
        7) superscript_str+="⁷" ;;
        8) superscript_str+="⁸" ;;
        9) superscript_str+="⁹" ;;
        *)
            # Handle non-digit characters if they somehow appear (e.g., decimal point)
            # For numbers, this case should ideally not be hit.
            superscript_str+="$digit"
            ;;
        esac
    done
    echo "$superscript_str"
}

# ----------------------
# Display the xbar menu
# ----------------------

# Display the main menu item with the cloud icon and color based on whether any tunnels are active
# If any tunnels are active, show the cloud icon in green, otherwise show it in black
if [[ "$ACTIVE" == "true" ]]; then
    #echo ":cloud: 2| color=green"

    # Convert the number to its superscript form
    superscripted_number=$(to_superscript "$number_of_active_tunnels")

    # Echo the output for xbar
    # Note: The superscript will appear *next* to the icon, not *over* it,
    # due to the limitations of text rendering in the menubar.
    echo ":cloud:${superscripted_number} | color=green"

else
    echo ":cloud:| color=black"
fi

# Display the menu items for each type of forward
# where active tunnels are shown in green and inactive ones in black
echo "---"
echo "Local Forwards | color=lightgray"
output_menu_items "local"
echo "---"
echo "Dynamic Forwards (SOCKS Proxies) | color=lightgray"
output_menu_items "dynamic"
echo "---"
echo " view log| shell='open' param1='$TUNNELS_LOGFILE'  terminal=false  "
echo " edit tunnels.json config | shell='open' param1='$TUNNELS_JSON_FILE'  terminal=false  "
echo "---"
echo "about easy-ssh-tunnels| href='https://github.com/harcokuppens/xbar-plugin-easy-ssh-tunnels'"
