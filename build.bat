@echo off
set steemdir=c:\steem\files
rem set steemdir=e:\games\steem\files
del z80.prg >NUL 2>&1
del %steemdir%\z80.prg >NUL 2>&1
rmac -px example_sndh.s -o z80.prg
copy z80.prg %steemdir%
