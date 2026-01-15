#!/usr/bin/env bash
# -*- coding: utf-8 -*-

function CLEAR_FILE() { 
    local files=("$@")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            true > "$file"
        fi
    done
}