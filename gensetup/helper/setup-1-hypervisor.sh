#!/bin/sh

# Create base 
qemu-img create -f qcow2 hardened-base.img 50G
# Create swap
qemu-img create -f qcow2 swap.img 5G
