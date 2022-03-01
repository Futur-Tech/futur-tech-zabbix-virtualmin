#!/usr/bin/env bash

[ -z "$1" ] && exit # Exit if missing Backup ID

jq_cmd="map(select(.DETAILS.\"Scheduled backup ID\" == \"${1}\")) | .[-1]"

virtualmin list-backup-logs --multiline \
    | sed -E 's|^[^ ]+|}},{ "INDEX":"\0", "DETAILS": {|g'   `# Add INDEX key and }},{` \
    | sed -E 's|^[ ]{4}(.+): (.+)$|"\1" : "\2",|g'          `# Put key and value with " "` \
    | tr '\n' ' '                                           `# Remove all line returns` \
    | sed 's|, }},{| }},{|g'                                `# Remove , at the end of the DETAILS array` \
    | sed -E 's|^\}\},\{|[{|g'                              `# Remove the }},{ at the beginning of the line and add [{` \
    | sed -E 's|, $|}}]|g'                                  `# Remove the , in the end and replace by }}]` \
    | jq "${jq_cmd}"                                        `# Process and Prettify the JSON`
