#/bin/sh
pandoc -f markdown -t html5 $1 | wl-copy --type text/html