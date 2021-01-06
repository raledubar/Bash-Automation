#!/bin/bash
for var in 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.00 1.01 1.02 1.03 1.04 1.05 1.06 1.07 1.08 1.09 1.10
do
gnuplot <<- EOF
set term png
set output "${var}_mb.dat.png"
plot "${var}_mb.dat" title "${var}_mb.dat"
EOF
done
