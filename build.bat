@echo off
rem
rem   Build the STUFF library.
rem
setlocal
set libname=stuff
set srclib=stuff

call src_go %srclib%
call src_getfrom sys sys.ins.pas
call src_getfrom util util.ins.pas
call src_getfrom string string.ins.pas
call src_getfrom file file.ins.pas
call src_insall %srclib% %libname%

call src_go %srclib%
call src_pas %srclib% csv_in %1
call src_pas %srclib% csv_out %1
call src_pas %srclib% htm_out %1
call src_pas %srclib% ihex %1
call src_pas %srclib% ihex_out %1
call src_pas %srclib% nameval %1
call src_pas %srclib% partref %1
call src_pas %srclib% partref_read_csv %1
call src_pas %srclib% qprint_read %1
call src_pas %srclib% wav_filt %1
call src_pas %srclib% wav_in %1
call src_pas %srclib% wav_out %1
call src_pas %srclib% %libname%_comblock %1

call src_lib %srclib% %libname%
call src_msg %srclib% %libname%
