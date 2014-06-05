#!/bin/bash
exec >/dev/null 2>&1
if /usr/sbin/ntpdate -u 208.74.184.18; then
  exit 0
else
  if /usr/sbin/ntpdate -u 208.74.184.19; then
    exit 0
  else
    logger -p cron.err "Cannot fetch network time."
    exit 1
  fi
fi
