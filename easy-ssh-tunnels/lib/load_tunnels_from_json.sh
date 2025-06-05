# Function to load tunnel configurations from a JSON file
# Arguments:
#   $1: Path to the JSON file
# Returns:
#   0 on success, non-zero on failure.
#   Populates the global TUNNEL_* associative arrays.
load_tunnels_from_json() {
    local json_file="$1"

    # Check if jq is installed
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed. Please install it to use this script." >&2
        echo "On macOS with Homebrew: brew install jq" >&2
        return 1
    fi

    # Check if the JSON file exists
    if [ ! -f "$json_file" ]; then
        echo "Error: JSON file '$json_file' not found." >&2
        return 1
    fi

    #echo "Reading tunnel configurations from '$json_file' using ASCII field and record delimiters"
    # --- Use ASCII unit separator (0x1F) as a field delimiter, which is safer for Bash ---
    # --- Use ASCII unit separator (0x1E) as a record delimiter, which is safer for Bash ---
    # note: when using null string as separator we will get into problems: null chars removed in variable jq_output!!
    local jq_output
    jq_output=$(jq -j '.[] | [ (.PORT | tostring), .LABEL, .TYPE, .EXPECT_WRAPPERS, .COMMAND ] | join("\u001F") + "\u001E"' "$json_file")

    local jq_exit_status=$?

    # Check if jq command was successful and produced any output
    if [ "$jq_exit_status" -ne 0 ]; then
        echo "Error: jq failed to parse JSON from '$json_file'." >&2
        return 1
    elif [ -z "$jq_output" ]; then
        echo "Warning: No data found in '$json_file' or jq produced empty output." >&2
        return 0 # Still return 0 as it might be valid empty data, or an empty array
    fi

    # Loop through the records (which are newline-separated lines)
    # The outer IFS=$'\n' splits the jq_output into individual record lines.
    while IFS= read -r -d $'\x1E' record_line; do # record separator is newline , fields within record_line separated with 1F
        # For each record line, use IFS=$'\x1F' (unit separator) to split it into individual fields.
        IFS=$'\x1F' read -r port label type wrapper command <<<"$record_line"

        # Populate the global bash associative arrays
        TUNNEL_LABELS[$port]="$label"
        TUNNEL_TYPE[$port]="$type"
        TUNNEL_EXPECT_WRAPPERS[$port]="$wrapper"
        TUNNEL_COMMANDS[$port]="$command"
    done <<<"$jq_output"

    return 0 # Success
}
