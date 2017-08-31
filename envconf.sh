#!/usr/bin/env bash

# Usage: envconf.sh (<template-dir> <template-dir> ...)
# Example: envconf.sh
#          envconf.sh /etc/nginx/conf.d
#
# By default, all .template files will be recursive found in /etc/nginx
#
# Finds uppercase variables only matching ${...} pattern, to not break
# and substitute nginx-variables, and then uses envsubst to create
# conf file in same dir as template.
#for f in ${1:-/etc/nginx/**/*.template}; do
for f in ${TEMPLATE_PATH:-/etc/nginx/**/*.template}; do
  if [ -f ${f} ]; then
    echo "Rendering template: ${f}"
    variables=$(echo $(grep -Eo '\${[A-Z_]+}' $f))
    envsubst "${variables}" < ${f} > ${f%.*}.conf;
  fi
done

exec "$@"
