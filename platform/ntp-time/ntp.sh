#!/bin/bash
exec >/dev/null 2>&1
if /usr/sbin/ntpdate -u utcnist.colorado.edu ; then
  exit 0
else
  if /usr/sbin/ntpdate -u utcnist2.colorado.edu ; then
    exit 0
  else
    logger -p cron.err "Cannot fetch network time."
    exit 1
  fi
fi
