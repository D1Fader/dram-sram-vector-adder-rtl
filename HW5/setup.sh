#!/bin/bash
complete -W "\`grep -oE '^[a-zA-Z0-9_.-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_.-]*$//'\`" make
module load questa/2026.1
module load syn/W-2024.09-SP2
