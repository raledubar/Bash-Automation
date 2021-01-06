#!/bin/bash
for var in 21.66 21.87 22.09 
do 
mkdir ${var}_energia_momento
cp momento.sh ${var}_energia_momento
done
for vol in 21.66 21.87 22.09
do
value_a=$(echo "$vol" |awk '{printf "%.9f", 2*$1 }')
value_c=$(echo "$vol" |awk '{printf "%.9f", 3*$1 }')
sed -i s/a=/a=$value_a/g ${vol}_energia_momento/momento.sh
sed -i s/c=/c=$value_c/g ${vol}_energia_momento/momento.sh
done
#for dosvar in 21.66 21.87 22.09 
#do
#cd ${dosvar}_energia_momento
#chmod +x momento.sh
#./momento.sh &
#wait
#cd ..
#done


