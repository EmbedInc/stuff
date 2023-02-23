@echo off
rem
rem   BUILD_LIB [-dbg]
rem
rem   Build the STUFF library.
rem
setlocal
call build_pasinit

call src_insall %srcdir% %libname%

call src_pas %srcdir% csv_in %1
call src_pas %srcdir% csv_out %1
call src_pas %srcdir% htm_out %1
call src_pas %srcdir% ihex %1
call src_pas %srcdir% ihex_out %1
call src_pas %srcdir% nameval %1
call src_pas %srcdir% qprint_read %1
call src_pas %srcdir% wav_filt %1
call src_pas %srcdir% wav_in %1
call src_pas %srcdir% wav_out %1
call src_pas %srcdir% %libname%_comblock %1

call src_lib %srcdir% %libname%
call src_msg %srcdir% %libname%
