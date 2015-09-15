#!/bin/bash
exec >/dev/null 2>&1
if /usr/sbin/ntpdate -u 0.north-america.pool.ntp.org; then
  exit 0
else
  if /usr/sbin/ntpdate -u 1.north-america.pool.ntp.org; then
    exit 0
  else
    logger -p cron.err "Cannot fetch network time."
    exit 1
  fi
fi
