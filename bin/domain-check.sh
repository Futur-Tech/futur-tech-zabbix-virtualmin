#!/usr/bin/env bash

[ -z "$1" ] && exit # Exit if missing domain name

virtualmin validate-domains --all-features --domain ${1} \
    | sed -n 2p \
    | sed -E 's|^    ||g'