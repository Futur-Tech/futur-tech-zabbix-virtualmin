#!/usr/bin/env bash

[ -z "$1" ] && exit # Exit if missing Backup ID

jq_cmd="map(select(.DETAILS.\"Scheduled backup ID\" == \"${1}\")) | .[-1]"

json_output=$(virtualmin list-backup-logs --multiline |
    sed -E 's|^[^ ]+|}},{ "INDEX":"\0", "DETAILS": {|g' `# Add INDEX key and }},{` |
    sed -E 's|^[ ]{4}(.+): (.*)$|"\1" : "\2",|g' `# Put key and value with " "` |
    tr '\n' ' ' `# Remove all line returns` |
    sed 's|, }},{| }},{|g' `# Remove , at the end of the DETAILS array` |
    sed -E 's|^\}\},\{|[{|g' `# Remove the }},{ at the beginning of the line and add [{` |
    sed -E 's|, $|}}]|g' `# Remove the , in the end and replace by }}]` |
    jq "${jq_cmd}") `# Process and Prettify the JSON`

# Extract the date strings from JSON using jq
started_date=$(echo "$json_output" | jq -r '.DETAILS.Started')
ended_date=$(echo "$json_output" | jq -r '.DETAILS.Ended')

# Convert date strings to epoch timestamps
started_epoch=$(date -d "$started_date" '+%s')
ended_epoch=$(date -d "$ended_date" '+%s')

# Add epoch timestamps to the JSON
json_output=$(echo "$json_output" | jq --arg started_epoch "$started_epoch" --arg ended_epoch "$ended_epoch" '.DETAILS.Started_epoch = ($started_epoch | tonumber) | .DETAILS.Ended_epoch = ($ended_epoch | tonumber)')

echo "$json_output"
