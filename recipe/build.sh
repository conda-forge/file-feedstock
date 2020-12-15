#!/usr/bin/env bash
# Get an updated config.sub and config.guess
cp $BUILD_PREFIX/share/gnuconfig/config.* .

./configure \
    --prefix="${PREFIX}" \
    --datadir="${PREFIX}/share" \
    --disable-silent-rules \
    --disable-dependency-tracking

make "-j${CPU_COUNT}"

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
make check
fi

make install
