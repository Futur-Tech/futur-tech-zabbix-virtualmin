#!/usr/bin/env bash

virtualmin list-scheduled-backups --multiline \
    | sed -E "s/^[^\ ]+/},{ \"INDEX\":\"\0\",/g" \ # Add INDEX key and },{
    | sed -E "s/^[\ ]{4}(.+): (.+)$/\"\1\" : \"\2\",/g" \ # Put key and value with " "
    | tr '\n' ' ' \ # Remove all line returns
    | sed -E "s/, \},\{/ \} , \{/g" \ # Add space in },{
    | sed -E "s/^\},(\{)/\[ \1/g" \ # Remove the }, at the beginning of the line and add [
    | sed -E "s/, $/ \} \]/g" \ # Remove the , in the end and replace by ]
    | python -m json.tool # Prettify the JSON
