{   Routines for reading from a CSV file.
}
module csv_in;
define csv_in_open;
define csv_in_close;
define csv_in_line;
define csv_in_field_str;
define csv_in_field_strn;
define csv_in_field_int;
define csv_in_field_fp;
define csvfield_null;
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';
{
********************************************************************************
*
*   Subroutine CSV_IN_OPEN (FNAM, CIN, STAT)
*
*   Open a CSV file for reading.  FNAM is the name of the CSV file.  The
*   mandatory ".csv" file name suffix may be omitted from FNAM.  CIN is returned
*   the CSV file reading state.  It will be completely initialized.  No
*   assumption is made about its previous state.
}
procedure csv_in_open (                {open CSV input file}
  in      fnam: univ string_var_arg_t; {CSV file name, ".csv" suffix may be omitted}
  out     cin: csv_in_t;               {returned CSV reading state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  file_open_read_text (fnam, '.csv', cin.conn, stat); {open the file}
  if sys_error(stat) then return;

  cin.buf.max := size_char(cin.buf.str);
  cin.buf.len := 0;
  cin.p := 1;
  cin.field := 0;
  cin.open := true;
  end;
{
********************************************************************************
*
*   Subroutine CSV_IN_CLOSE (CIN, STAT)
*
*   Close the connection to the CSV file.  The closed/opened state is kept in
*   CIN.  Nothing is done if the state is already closed.  It is permissible to
*   call this routine multiple times after reading a CSV file.  The file will be
*   closed the first time, with the remaining times having no effect.
*
*   However, the closed/opened state is not valid in a totally uninitialized
*   CIN.  This routine must only be called after CIN is initialized, which is
*   done by CSV_IN_OPEN.
}
procedure csv_in_close (               {close CSV input file}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  if not cin.open then return;         {already closed ?}

  file_close (cin.conn);               {close the connection to the file}
  cin.open := false;                   {indicate no file open}
  end;
{
********************************************************************************
*
*   Subroutine CSV_IN_LINE (CIN, STAT)
*
*   Read the next line from the CSV file open on CIN.  The line is read into
*   CIN.BUF.
*
*   This routine automatically skips over blank lines, and lines where the first
*   non-blank character is a star (*).  These are considered comment lines.
*
*   The input line parse index, CIN.P, is left indicating the first non-blank
*   character of the input line.  Except when returning with error or end of
*   file, CIN.BUF always contains at least one non-blank character.
}
procedure csv_in_line (                {read next line from CSV file}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  cin.field := 0;                      {init to not read any field this line}

  while true do begin                  {skip over comment lines}
    file_read_text (cin.conn, cin.buf, stat); {read the next line from the file}
    if sys_error(stat) then begin      {error or EOF ?}
      cin.buf.len := 0;                {set new line to empty}
      cin.p := 1;
      return;
      end;

    string_unpad (cin.buf);            {remove trailing spaces from input line}
    if cin.buf.len = 0 then next;      {skip over blank lines}
    cin.p := 1;                        {init input line parse index}
    while cin.buf.str[cin.p] = ' ' do begin {skip over leading blanks}
      cin.p := cin.p + 1;
      end;
    if cin.buf.str[cin.p] = '*' then next; {skip explicit comment lines}
    exit;                              {new input line is all set}
    end;
  end;
{
********************************************************************************
*
*   Subroutine CSV_IN_FIELD_STR (CIN, STR, STAT)
*
*   Read the contents of the next field in the current input line and return it
*   in STR.  STAT is returned with EOS status when there is no new field to
*   read on the current line.
}
procedure csv_in_field_str (           {read next field from current CSV input line}
  in out  cin: csv_in_t;               {CSV file reading state}
  in out  str: univ string_var_arg_t;  {returned field contents}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  string_token_comma (cin.buf, cin.p, str, stat); {get the next field contents}
  cin.field := cin.field + 1;          {update number of last field read this line}
  end;
{
********************************************************************************
*
*   Subroutine CSV_IN_FIELD_STRN (CIN, STR, STAT)
*
*   Read the contents of the next field in the current input line and return it
*   in STR.  If the end of the current input line is encountered instead of
*   another field, then STR is returned the empty string and STAT indicating no
*   error.
}
procedure csv_in_field_strn (          {read next CSV field, no EOS error}
  in out  cin: csv_in_t;               {CSV file reading state}
  in out  str: univ string_var_arg_t;  {returned field contents, empty on EOS}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  csv_in_field_str (cin, str, stat);   {try to get next field contents}
  if string_eos(stat) then begin       {hit end of line instead ?}
    str.len := 0;
    end;
  end;
{
********************************************************************************
*
*   Function CSV_IN_FIELD_INT (CIN, STAT)
*
*   Read the next field on the current CSV input line and return its integer
*   value.  It is a error if the field string can not be interpreted as a
*   integer.
}
function csv_in_field_int (            {get next CSV line field as integer}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t)             {completion status}
  :sys_int_max_t;                      {returned field value, 0 on error}
  val_param;

var
  str: string_var80_t;                 {field string}
  ii: sys_int_max_t;                   {integer field value}

begin
  str.max := size_char(str.str);       {init local var string}
  csv_in_field_int := 0;               {init to value for error}

  csv_in_field_str (cin, str, stat);   {get the next field string into STR}
  if sys_error(stat) then return;
  if str.len = 0 then begin            {this field is empty ?}
    sys_stat_set (stuff_subsys_k, stuff_stat_csvfield_null_k, stat);
    sys_stat_parm_vstr (cin.conn.tnam, stat); {file name}
    sys_stat_parm_int (cin.conn.lnum, stat); {line number}
    sys_stat_parm_int (cin.field, stat); {field number}
    return;
    end;

  string_t_int_max (str, ii, stat);    {convert to integer value}
  if sys_error(stat) then return;

  csv_in_field_int := ii;              {return the integer value}
  end;
{
********************************************************************************
*
*   Function CSV_IN_FIELD_FP (CIN, STAT)
*
*   Read the next field on the current CSV input line and return its floating
*   point value.  It is a error if the field string can not be interpreted as a
*   floating point number.
}
function csv_in_field_fp (             {get next CSV line field as floating point}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t)             {completion status}
  :sys_fp_max_t;                       {returned field value, 0.0 on error}
  val_param;

var
  str: string_var80_t;                 {field string}
  fp: sys_fp_max_t;                    {floating point value}

begin
  str.max := size_char(str.str);       {init local var string}
  csv_in_field_fp := 0.0;              {init to value for error}

  csv_in_field_str (cin, str, stat);   {get the next field string into STR}
  if sys_error(stat) then return;
  if str.len = 0 then begin            {this field is empty ?}
    sys_stat_set (stuff_subsys_k, stuff_stat_csvfield_null_k, stat);
    sys_stat_parm_vstr (cin.conn.tnam, stat); {file name}
    sys_stat_parm_int (cin.conn.lnum, stat); {line number}
    sys_stat_parm_int (cin.field, stat); {field number}
    return;
    end;

  string_t_fpmax (                     {convert filed string to floating point}
    str,                               {input string}
    fp,                                {output floating point}
    [],                                {no special rules}
    stat);
  if sys_error(stat) then return;

  csv_in_field_fp := fp;               {return the floating value}
  end;
{
********************************************************************************
*
*   Function CSVFIELD_NULL (STAT)
*
*   Returns TRUE iff STAT is indicating STUFF_STAT_CSVFIELD_NULL_K.  This error
*   indicates a CSV file field is empty.  When returning TRUE, STAT is reset to
*   indicate no error.
}
function csvfield_null (               {check for empty CSV file field}
  in out  stat: sys_err_t)             {STAT to test, reset on returning TRUE}
  :boolean;                            {STAT is indicating empty CSV file field}
  val_param;

begin
  csvfield_null := true;               {init to the field was empty}

  if sys_stat_match (stuff_subsys_k, stuff_stat_csvfield_null_k, stat)
    then return;
  if string_eos(stat) then return;

  csvfield_null := false;
  end;
