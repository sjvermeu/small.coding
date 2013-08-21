#!/bin/sh

hostname_get() {
  host $(ip -6 addr show dev eth0 scope global | grep inet6 | awk '{print $2}' | sed -e 's|/.*||g') | awk '{print $NF}' | sed -e 's:\.$::g';
}
