#!/bin/sh
set -e
/sdrpp/sdrplay_apiService &
exec /sdrpp/sdrpp -s -r /sdrpp/conf.d
