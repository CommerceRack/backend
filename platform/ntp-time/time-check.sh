#!/bin/bash

MACHINES="db1 app1 app6 app7 app8 snap crackle pop dagobah z102 z104 z105 z106 z108 z127 z140 z145 z150 z155 z160 z165 z170 z180 z185 z190 z195 z200 z201 z202 z205 z51 z52 z53 z54 z55 z57 z58 z60 z62 z63 z64 z84 z85 z86 z87 z88 z89 z90 z91 z92 z94 z95"
 
for m in $MACHINES
	do
         	ssh root@$m 'echo $HOSTNAME'
		ssh root@$m 'date'
        done
