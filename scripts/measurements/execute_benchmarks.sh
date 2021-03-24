#!/bin/bash
source prepare_re2_test.sh
source prepare_re2_test.sh
benchmarks=(protomata snort brill clamAV)
for i in ${benchmarks[@]}
do
	python3 measure.py -re2chrono -regfile="$i.regex" -strfile="$i.input" -format=pcre -endstr=$(cat $i.input | wc -l) -endreg=$(cat $i.regex | wc -l)
done
