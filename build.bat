@echo off
set steemdir=c:\steem\files
del example.prg >NUL 2>&1
del %steemdir%\example.prg >NUL 2>&1
bin\rmac -l*example.lst -s -px -D_RMAC_=1 -D_VASM_=0 -o %steemdir%\example.prg example.s
