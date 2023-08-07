#!/usr/bin/env bash

virtualmin list-domains --name-only --enabled |
    sed -E 's|^.+|{ "domain" : "\0" },|g' |
    tr '\n' ' ' |
    sed -E 's|^(.+), $|[ \1 ]|g' |
    jq "." `# Process and Prettify the JSON`
