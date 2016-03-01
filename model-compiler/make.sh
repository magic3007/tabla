#!/bin/bash

if [[ "$1" = "clean" ]]; then
    rm -rf ./artifacts/
    rm *.*~
else
    for dotfile in *.dot; do
	jpeg=${dotfile%.dot}.jpeg
	dot -Tjpeg $dotfile -o $jpeg
    done
    mkdir ./artifacts/
    mv *.dot *.json ./artifacts
    mv *.jpeg ./jpegs
fi
