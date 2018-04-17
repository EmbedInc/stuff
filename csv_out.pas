{   Routines for writing to a CSV file.
}
module csv_out;
define csv_out_open;
define csv_out_blank;
define csv_out_vstr;
define csv_out_str;
define csv_out_int;
define csv_out_fp_free;
define csv_out_fp_fixed;
define csv_out_fp_ftn;
define csv_out_line;
define csv_out_close;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
{
********************************************************************************
*
*   Subroutine CSV_OUT_OPEN (FNAM, CSV, STAT)
*
*   Open a CSV file for writing.  FNAM is the CSV file name.  The ".csv" file
*   name suffix may be omitted from FNAM, but the name of the file actually
*   opened will always end in ".csv".  CSV is the returned writing state for
*   this CSV file.  It is passed to subsequent CSV_OUT_xxx routines to identify
*   the particular CSV file being written to and its current state.
}
procedure csv_out_open (               {open CSV output file}
  in      fnam: univ string_var_arg_t; {CSV file name, ".csv" suffix may be omitted}
  out     csv: csv_out_t;              {returned CSV file writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  file_open_write_text (fnam, '.csv'(0), csv.conn, stat); {open the CSV output file}
  if sys_error(stat) then return;

  csv.buf.max := size_char(csv.buf.str); {init current output line to empty}
  csv.buf.len := 0;
  csv.open := true;
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_BLANK (CSV, N, STAT)
*
*   Write a field containing only 0 or more blanks.  The blanks will not be
*   written as a quoted string.  This is the typical way to indicate no value
*   is being supplied for the field.
*
*   N is the number of blanks to write and can be zero or more.
}
procedure csv_out_blank (              {write completely blank field, not quoted}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      n: sys_int_machine_t;        {number of blanks to write}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  ii: sys_int_machine_t;

begin
  sys_error_none (stat);               {init to no error encountered}

  if csv.buf.len > 0 then begin        {there is a previous field on this line ?}
    string_append1 (csv.buf, ',');     {write comma separator from prevous field}
    end;

  for ii := 1 to n do begin            {write the blanks}
    string_append1 (csv.buf, ' ');
    end;
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_VSTR (CSV, VSTR, STAT)
*
*   Write a arbitrary string as the next CSV file field.  VSTR is a normal Embed
*   var string.
}
procedure csv_out_vstr (               {var string as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      vstr: univ string_var_arg_t; {string to write as single field}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  if csv.buf.len > 0 then begin        {there is a previous field on this line ?}
    string_append1 (csv.buf, ',');     {write comma separator from prevous field}
    end;
  string_append_token (csv.buf, vstr); {write the string as a single token}
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_STR (CSV, STR, STAT)
*
*   Write the Pascal string in STR as the next field of the current CSV output
*   line.  Trailing blanks of STR are ignored, and the first zero character, if
*   present, is interpreted as a end of string marker.  STR is therefore
*   compatible with string literals of both Pascal and C.
}
procedure csv_out_str (                {string as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      str: string;                 {string to write as field, trailing blanks ignored}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var8192_t;                {input string converted to VAR string}

begin
  tk.max := size_char(tk.str);         {init local var string}
  string_vstring (tk, str, size_char(str)); {convert input string to var string}
  csv_out_vstr (csv, tk, stat);        {write field value from var string}
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_INT (CSV, I, STAT)
*
*   Write the integer value I as the next field of the current CSV file output
*   line.
}
procedure csv_out_int (                {write integer as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      i: sys_int_max_t;            {integer value}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var32_t;                  {integer string}

begin
  tk.max := size_char(tk.str);         {init local var string}
  string_f_int_max (tk, i);            {convert integer to string}
  csv_out_vstr (csv, tk, stat);        {write the string as next field}
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_FP_FREE (CSV, FP, SIG, STAT)
*
*   Write the floating point value FP as the next field of the current CSV file
*   output line.  Free format is used with a minimum of SIG significant digits.
}
procedure csv_out_fp_free (            {write free format floating point as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      fp: double;                  {floating point value to write}
  in      sig: sys_int_machine_t;      {number of significant digits}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var32_t;                  {integer string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp (                        {convert FP to string representation}
    tk,                                {output string}
    fp,                                {input floating point value}
    0,                                 {field width, 0 = free form}
    0,                                 {exponent field width, 0 = free form}
    sig,                               {min required significant digits}
    sig,                               {max allowed digits left of point}
    sig, sig,                          {min and max allowed digits right of point}
    [],                                {no special options}
    stat);
  if sys_error(stat) then return;
  csv_out_vstr (csv, tk, stat);        {write the string as next field}
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_FP_FIXED (CSV, FP, DIGR, STAT)
*
*   Write the floating point value FP as the next field of the current CSV file
*   output line.  Fixed format is used with DIGR digits right of the decimal
*   point.
}
procedure csv_out_fp_fixed (           {write fixed format floating point as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      fp: double;                  {floating point value to write}
  in      digr: sys_int_machine_t;     {digits right of decimal point}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var80_t;                  {integer string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp (                        {convert FP to string representation}
    tk,                                {output string}
    fp,                                {input floating point value}
    0,                                 {field width, 0 = free form}
    0,                                 {exponent field width, 0 = free form}
    0,                                 {min required significant digits}
    60,                                {max allowed digits left of point}
    digr, digr,                        {min and max allowed digits right of point}
    [],                                {no special options}
    stat);
  if sys_error(stat) then return;
  csv_out_vstr (csv, tk, stat);        {write the string as next field}
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_FP_FTN (CSV, FP, FW, DIGR, STAT)
*
*   Write the floating point value FP as the next field of the current CSV file
*   output line.  Fortran formatting is used.  FW is the total width of the
*   number.  This includes any leading minus sign, digits left of the point, the
*   point, and digits right of the point.  DIGR is the fixed number of digits to
*   always write right of the point.
*
*   If the number is too large to fit into the field, then it is written wider
*   as needed.
}
procedure csv_out_fp_ftn (             {write FP as next CSV field, FTN formatting}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      fp: double;                  {floating point value to write}
  in      fw: sys_int_machine_t;       {minimum total number width}
  in      digr: sys_int_machine_t;     {digits right of decimal point}
  out     stat: sys_err_t);            {completion status}
  val_param;

var
  tk: string_var80_t;                  {integer string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp (                        {convert FP to string representation}
    tk,                                {output string}
    fp,                                {input floating point value}
    fw,                                {field width, 0 = free form}
    0,                                 {exponent field width, 0 = free form}
    0,                                 {min required significant digits}
    60,                                {max allowed digits left of point}
    digr, digr,                        {min and max allowed digits right of point}
    [],                                {no special options}
    stat);
  if sys_error(stat) then begin        {couldn't fit in field or some other error ?}
    string_f_fp (                      {try with as wide a field as it takes}
      tk,                              {output string}
      fp,                              {input floating point value}
      0,                               {field width, 0 = free form}
      0,                               {exponent field width, 0 = free form}
      0,                               {min required significant digits}
      60,                              {max allowed digits left of point}
      digr, digr,                      {min and max allowed digits right of point}
      [],                              {no special options}
      stat);
    if sys_error(stat) then return;    {give up is still couldn't make work}
    end;

  if csv.buf.len > 0 then begin        {there is a previous field on this line ?}
    string_appendn (csv.buf, ', ', 2); {write comma separator from prevous field}
    end;
  string_append (csv.buf, tk);         {write the number string}
  end;
{
********************************************************************************
*
*   Subroutine CSV_OUT_LINE (CSV, STAT)
*
*   Write the current output line that has been built to the CSV file.  The
*   current output line is reset to empty.
}
procedure csv_out_line (               {write curr line to CSV file, will be reset to empty}
  in out  csv: csv_out_t;              {CSV file writing state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  file_write_text (csv.buf, csv.conn, stat); {write line to CSV output file}
  if sys_error(stat) then return;
  csv.buf.len := 0;                    {reset the current output line to empty}
  end;
{
********************************************************************************
*
*   CSV_OUT_CLOSE (CSV, STAT)
*
*   Close the CSV output file.  If a partial output line has been built, it is
*   written to the file before the file is closed.  Nothing is done if there is
*   no open connection to the CSV output file.
}
procedure csv_out_close (              {close CSV output file}
  in out  csv: csv_out_t;              {CSV file writing state, returned invalid}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}
  if not csv.open then return;         {already closed, nothing more to do ?}

  if csv.buf.len > 0 then begin        {unwritten output line exists ?}
    csv_out_line (csv, stat);          {write the current output file line}
    if sys_error(stat) then return;
    end;

  file_close (csv.conn);               {close the file}
  csv.open := false;                   {indicate no connection now open}
  end;
