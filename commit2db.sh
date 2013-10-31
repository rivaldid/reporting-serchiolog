#!/usr/bin/env bash

time find ./xpsbucket -iname *.xps -exec perl serchiolog.pl {} \;
