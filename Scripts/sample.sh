#!/bin/bash

# Put Your config Here
LOCALIZE_PATH=""
LOCALIZE_API=""
LOCALIZE_TOKEN=""

# Config for Strings struct (Optional to change)
STRINGS_STRUCT_NAME="Strings"

./localize.sh $1 "$(realpath "$LOCALIZE_PATH")" "$LOCALIZE_API" "$LOCALIZE_TOKEN" "$STRINGS_STRUCT_NAME"
