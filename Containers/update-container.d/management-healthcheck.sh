#!/bin/bash

if ! nc -z 127.0.0.1 9001; then
    exit
fi
