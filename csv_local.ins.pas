{   This include file creates local wrapper routines for writing to a CSV output
*   file.  STUFF.INS.PAS must have been previously included.
*
*   The details of each routine are documented in the comment headers of the
*   routines.  Briefly, the routines are:
*
*     WCSV_OPEN (FNAM, STAT)
*
*     WCSV_VSTR (VSTR)
*
*         Write var string to next field.
*
*     WCSV_STR (STR)
*
*         Write Pascal string to next field.
*
*     WCSV_INT (I)
*
*         Write integer value to next field.
*
*     WCSV_FP_FIXED (FP, DIGR)
*
*         Write floating point value to next field, fixed digits right of point.
*
*     WCSV_FP_FTN (FP, FW, DIGR)
*
*         Write floating point value to next field, Fortran formatting.
*
*     WCSV_FP_FREE (FP, SIG)
*
*         Write floating point value to next field, free format with minimum
*         required significant digits.
*
*     WCSV_LINE
*
*         End current line.
*
*     WCSV_CLOSE
}
var
  csv_out_p: csv_out_p_t := nil;       {points to current CSV file writing state}
{
********************************************************************************
*
*   Subroutine WCSV_OPEN (FNAM, STAT)
}
procedure wcsv_open (                  {open CSV output file}
  in      fnam: univ string_var_arg_t; {file name, ".csv" suffix implied}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  if csv_out_p = nil then begin        {no CSV file writing state exists ?}
    sys_mem_alloc (sizeof(csv_out_p^), csv_out_p); {create new CSV file writing state}
    csv_out_p^.open := false;          {init to no connection to a file}
    end;

  csv_out_open (fnam, csv_out_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_VSTR (VSTR)
}
procedure wcsv_vstr (                  {write field from var string}
  in      vstr: univ string_var_arg_t); {the string to write, trailing blanks ignored}
  val_param;

var
  stat: sys_err_t;

begin
  csv_out_vstr (csv_out_p^, vstr, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_STR (STR)
}
procedure wcsv_str (                   {write field from Pascal string}
  in      str: string);                {the string to write, trailing blanks ignored}
  val_param;

var
  stat: sys_err_t;

begin
  csv_out_str (csv_out_p^, str, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_INT (II)
}
procedure wcsv_int (                   {write integer field}
  in      ii: sys_int_max_t);          {integer value to write}
  val_param;

var
  stat: sys_err_t;

begin
  csv_out_int (csv_out_p^, ii, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_FP_FIXED (FP, DIGR)
}
procedure wcsv_fp_fixed (              {write floating point field in fixed format}
  in      fp: double;                  {value to write}
  in      digr: sys_int_machine_t);    {digits right of point}
  val_param;

var
  stat: sys_err_t;

begin
  csv_out_fp_fixed (csv_out_p^, fp, digr, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_FP_FTN (FP, FW, DIGR)
}
procedure wcsv_fp_ftn (                {write floating point field, FTN formatting}
  in      fp: double;                  {value to write}
  in      fw: sys_int_machine_t;       {total number fixed field width}
  in      digr: sys_int_machine_t);    {digits right of point}
  val_param;

var
  stat: sys_err_t;

begin
  csv_out_fp_ftn (csv_out_p^, fp, fw, digr, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_FP_FREE (FP, SIG)
}
procedure wcsv_fp_free (               {write floating point field in free format}
  in      fp: double;                  {value to write}
  in      sig: sys_int_machine_t);     {significant digits}
  val_param;

var
  stat: sys_err_t;

begin
  csv_out_fp_free (csv_out_p^, fp, sig, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_LINE
}
procedure wcsv_line;                   {write current line to CSV file}

var
  stat: sys_err_t;

begin
  csv_out_line (csv_out_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine WCSV_CLOSE
}
procedure wcsv_close;                  {close the CSV output file}

var
  stat: sys_err_t;

begin
  csv_out_close (csv_out_p^, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
