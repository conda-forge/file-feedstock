#!/usr/bin/env bash

./configure \
    --prefix="${PREFIX}" \
    --datadir="${PREFIX}/share" \
    --disable-silent-rules \
    --disable-dependency-tracking

make "-j${CPU_COUNT}"

make check

make install
