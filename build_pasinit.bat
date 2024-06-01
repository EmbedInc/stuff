@echo off
rem
rem   Set up for building a Pascal module.
rem
call build_vars

call src_get %srcdir% %libname%.ins.pas
call src_get %srcdir% %libname%2.ins.pas

call :dolocal csv_local.ins.pas
call :dolocal nextin_local.ins.pas
call :dolocal send_local.ins.pas
call :dolocal whtm_local.ins.pas
call :dolocal wout_local.ins.pas

call src_getbase

goto :eof

rem ****************************************************************************
rem
rem   Subroutine DOLOCAL fnam
rem
:dolocal
call src_get %srcdir% "%~1"
copya "%~1" "(cog)lib/%~1"
goto :eof
