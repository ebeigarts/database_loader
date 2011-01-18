#!/bin/sh
echo "usage: $0 username password"

MYDIR=`pwd`

for sql_dir in views materialized_views packages indexes scripts do
do
  if test -r ${MYDIR}/${sql_dir}
  then
    for sql_file in ${MYDIR}/${sql_dir}/*
    do
      if test -r ${sql_file}
      then
        echo create ${sql_dir} ${sql_file}
        sqlplus -s $1/$1 @${sql_file}
      fi
    done
  fi
done
