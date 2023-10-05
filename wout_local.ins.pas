{   This include file defines local routines for writing items to standard
*   output.
*
*   The facilities from this file that applications are intended to interact
*   are listed here.  See header comments of routines for more details.
*
*   WOUT_INIT
*
*     Must be called once before any other resources from this file are used.
*
*   NEWLINE
*
*     Boolean variable that indicates the output is currently at the start of
*     a new line.  The application must update this when this state is known
*     to change outside of this file.
*
*   LOCKOUT
*
*     Subroutine to acquire exclusive lock on writing to standard output.
*
*   UNLOCKOUT
*
*     Subroutine to release the output writing lock acquired by LOCKOUT.
*
*   WHEX4 (I)
*
*     Writes the 4 bit value of I as 1 HEX digit.
*
*   WHEX (B)
*
*     Writes the 8 bit byte value as two HEX digits.
*
*   WHEX12 (I)
*
*     Writes the 12 bit value of I as 3 HEX digits.
*
*   WHEX16 (I)
*
*     Writes the 16 bit value of I as 4 HEX digits.
*
*   WHEX20 (I)
*
*     Writes the 20 bit value of I as 5 HEX digits.
*
*   WHEX24 (I)
*
*     Writes the 24 bit value of I as 6 HEX digits.
*
*   WHEX28 (I)
*
*     Writes the 28 bit value of I as 7 HEX digits.
*
*   WHEX32 (I)
*
*     Writes the 32 bit value of I as 8 HEX digits.
*
*   WDEC (B)
*
*     Write the byte value as three decimal digits.
*
*   WCHAR (C)
*
*     Shows the value of character C as HEX, decimal, and character.  Some
*     control characters are interpreted and their name shown.
*
*   WBYTES (B, N)
*
*     Show the value of the N bytes starting at B.  The bytes are shown on two
*     standard output lines, the first in HEX and the second in decimal.  Only
*     up to the first 16 bytes are shown, since that is all that fits on a line.
*     If N is more than 16, then elipses ("...") are shown after the last byte.
*
*   WIRANGE (I1, I2)
*
*     Show the integer range from I1 to I2.  If both numbers are the same, then
*     only the single integer value is shown.  If I2 is exactly I1+1, then they
*     are written as separate integer values with a space between.  Otherwise,
*     I1 and I2 are written with a dash (-) between them.
*
*   WENG (FP, ND, UNIT)
*
*     Writes FP in engineering notation.  The FP value is written normalized to
*     the engineering power of 1000, then a space, then the abbreviation for
*     that power of 1000, then the UNIT string.
*
*   WFP (FP, ND)
*
*     Write the floating point value FP with ND digits right of the decimal
*     point.
}
type
  wbyte_array_t = array[0..1] of int8u_t;

  wout_proc_p_t = ^procedure;

var
  wrlock: sys_sys_threadlock_t;        {lock for writing to standard output}
  newline: boolean;                    {STDOUT stream is at start of new line}
  lockout_p: wout_proc_p_t;            {to externally supplied LOCKOUT routine}
  unlockout_p: wout_proc_p_t;          {to externally supplied UNLOCKOUT routine}
  wout_atnew_p: wout_proc_p_t;         {to externally supplied WOUT_ATNET routine}
  wout_notnew_p: wout_proc_p_t;        {to externally supplied WOUT_NOTNEW routine}
{
********************************************************************************
*
*   Subroutine WOUT_INIT
*
*   This routine must be called before any other resources from this file are
*   used.
}
procedure wout_init;
  val_param; internal;

var
  stat: sys_err_t;

begin
  sys_thread_lock_create (wrlock, stat); {create interlock for writing to STDOUT}
  sys_error_abort (stat, '', '', nil, 0);
  newline := true;
  lockout_p := nil;
  unlockout_p := nil;
  wout_atnew_p := nil;
  wout_notnew_p := nil;
  end;
{
********************************************************************************
*
*   Subroutine WOUT_ATNEW
*
*   This routine is called when the applications knows that standard output is
*   at the start of a new line.
}
procedure wout_atnew;                  {STD out is at the start of a new line}
  val_param;

begin
  if wout_atnew_p <> nil then begin    {routine externally supplied ?}
    wout_atnew_p^;                     {call the external routine}
    return;
    end;

  newline := true;
  end;
{
********************************************************************************
*
*   Subroutine WOUT_NOTNEW
*
*   Called to indicate that standard output is not at the start of a new line.
}
procedure wout_notnew;                 {STD out is not at the start of a new line}
  val_param;

begin
  if wout_notnew_p <> nil then begin   {routine externally supplied ?}
    wout_notnew_p^;                    {call the external routine}
    return;
    end;

  newline := false;
  end;
{
********************************************************************************
*
*   Subroutine LOCKOUT
*
*   Acquire exclusive lock for writing to standard output.  If both a lock on standard
*   output and the histogram data are desired, standard output must always be locked
*   first.
}
procedure lockout;
  val_param;

begin
  if lockout_p <> nil then begin       {routine externally supplied ?}
    lockout_p^;                        {call the external routine}
    return;
    end;

  sys_thread_lock_enter (wrlock);
  if not newline then writeln;         {start on a new line}
  newline := true;                     {init to STDOUT will be at start of line}
  end;
{
********************************************************************************
*
*   Subroutine UNLOCKOUT
*
*   Release exclusive lock for writing to standard output.
}
procedure unlockout;
  val_param;

begin
  if unlockout_p <> nil then begin     {routine externally supplied ?}
    unlockout_p^;                      {call the external routine}
    return;
    end;

  sys_thread_lock_leave (wrlock);
  end;
{
********************************************************************************
*
*   Subroutine WHEX4 (I)
*
*   Write the value in the low 4 bits of I as 1 hexadecimal digit to standard
*   output.
}
procedure whex4 (                      {write 4 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 4 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#F,                          {input integer}
    16,                                {radix}
    1,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX (B)
*
*   Write the byte value in the low 8 bits of B as two hexadecimal digits
*   to standard output.
}
procedure whex (                       {write hex byte to standard output}
  in      b: sys_int_machine_t);       {byte value in low 8 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    b & 255,                           {input integer}
    16,                                {radix}
    2,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX12 (I)
*
*   Write the value in the low 12 bits of I as 3 hexadecimal digits to standard
*   output.
}
procedure whex12 (                     {write 12 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 12 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#FFF,                        {input integer}
    16,                                {radix}
    3,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX16 (I)
*
*   Write the value in the low 16 bits of I as 4 hexadecimal digits to standard
*   output.
}
procedure whex16 (                     {write 16 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 16 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#FFFF,                       {input integer}
    16,                                {radix}
    4,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX20 (I)
*
*   Write the value in the low 20 bits of I as 5 hexadecimal digits to standard
*   output.
}
procedure whex20 (                     {write 20 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 20 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#FFFFF,                      {input integer}
    16,                                {radix}
    5,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX24 (I)
*
*   Write the value in the low 24 bits of I as 6 hexadecimal digits to standard
*   output.
}
procedure whex24 (                     {write 24 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 24 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#FFFFFF,                     {input integer}
    16,                                {radix}
    6,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX28 (I)
*
*   Write the value in the low 28 bits of I as 7 hexadecimal digits to standard
*   output.
}
procedure whex28 (                     {write 28 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 28 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#FFFFFFF,                    {input integer}
    16,                                {radix}
    7,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WHEX32 (I)
*
*   Write the value in the low 32 bits of I as 8 hexadecimal digits to standard
*   output.
}
procedure whex32 (                     {write 32 bit HEX word to standard output}
  in      i: sys_int_machine_t);       {value to write in low 32 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    i & 16#FFFFFFFF,                   {input integer}
    16,                                {radix}
    8,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WDEC (B)
*
*   Write the byte value in the low 8 bits of B as an unsigned decimal
*   integer to standard output.  Exactly 3 characters are written with
*   leading zeros as blanks.
}
procedure wdec (                       {write byte to standard output in decimal}
  in      b: sys_int_machine_t);       {byte value in low 8 bits}
  val_param;

var
  tk: string_var16_t;                  {hex string}
  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    b & 255,                           {input integer}
    10,                                {radix}
    3,                                 {field width}
    [string_fi_unsig_k],               {the input integer is unsigned}
    stat);
  write (tk.str:tk.len);               {write the string to standard output}
  end;
{
********************************************************************************
*
*   Subroutine WCHAR (C)
*
*   Write the character C in ASCII and its HEX and decimal value.
}
procedure wchar (                      {write character value}
  in      c: char);                    {character to write value of}
  val_param;

var
  ii: sys_int_machine_t;               {integer value of the character}
  s: string_var32_t;                   {full string to write}
  tk: string_var32_t;                  {scratch token}
  stat: sys_err_t;

begin
  s.max := size_char(s.str);           {init local var strings}
  tk.max := size_char(tk.str);
  s.len := 0;                          {init result string to empty}
  ii := ord(c);                        {get character integer value}
{
*   Show hexadecimal value.
}
  string_f_int_max_base (              {make the hex string}
    tk,                                {output string}
    ii & 255,                          {input integer}
    16,                                {radix}
    2,                                 {field width}
    [ string_fi_leadz_k,               {pad field on left with leading zeros}
      string_fi_unsig_k],              {the input integer is unsigned}
    stat);
  string_append (s, tk);
{
*   Show decimal value.
}
  string_f_int_max_base (              {make 3 digit decimal with leading blank}
    tk, ii, 10, 4, [string_fi_unsig_k], stat);
  string_append (s, tk);
{
*   Show character value.
}
  string_append1 (s, ' ');
  case ii of                           {check for special characters to show}
7:  string_appendn (s, 'Bel', 3);      {bell}
10: string_appendn (s, ' LF', 3);      {carriage return}
13: string_appendn (s, ' CR', 3);      {line feed}
255: string_appendn (s, 'Rub', 3);     {rub out}
otherwise
    if ii < 32
      then begin                       {control character}
        string_appendn (s, '---', 3);
        end
      else begin                       {printable character}
        string_appendn (s, '  ', 2);
        string_append1 (s, c);
        end
      ;
    end;

  write (s.str:s.len);
  end;
{
********************************************************************************
*
*   Subroutine WBYTES (BARR, N)
*
*   Show the first N bytes in the bytes array BARR.
}
procedure wbytes (                     {write array of bytes}
  in      barr: univ wbyte_array_t;    {array of bytes}
  in      n: sys_int_machine_t);       {number of bytes to write values of}
  val_param;

const
  maxshow = 16;                        {max bytes to show}

var
  nshow: sys_int_machine_t;            {number of byte values to actually show}
  ii: sys_int_machine_t;               {loop counter}

begin
  nshow := max(0, min(maxshow, n));    {determine how many bytes to actually show}
  if nshow = 0 then return;            {nothing to do ?}

  write ('  hex:');
  for ii := 0 to nshow-1 do begin
    write ('  ');
    whex (barr[ii]);
    end;
  if nshow < n then write (' ...');
  writeln;

  write ('  dec:');
  for ii := 0 to nshow-1 do begin
    write (' ');
    wdec (barr[ii]);
    end;
  if nshow < n then write (' ...');
  writeln;
  end;
{
********************************************************************************
*
*   Subroutine WIRANGE (I1, I2)
*
*   Show the integer range from I1 to I2.
}
procedure wirange (                    {show start/end range of numbers}
  in      i1, i2: sys_int_machine_t);  {start and end of range}
  val_param;

begin
  write (i1);                          {write the first value}
  if i2 = i1 then return;              {second number is the same, don't show it ?}
  if i2 = (i1 + 1)
    then write (' ')
    else write ('-');
  write (i2);                          {show second number}
  end;
{
********************************************************************************
*
*   Subroutine WENG (FP, ND, UNIT)
*
*   Write FP in engineering notation.  The FP value is written normalized to the
*   engineering power of 1000, then a space, then the abbreviation for that
*   power of 1000, then the UNIT string.  ND is the minimum number of
*   significant digits to show.
*
*   For example, weng(1234.56, 3, 'Hz') will result in "1.23 kHz", and
*   weng(1234.56, 4, '') will result in "1.235 k".
}
procedure weng (                       {show number in engineering notation}
  in      fp: real;                    {the value to show}
  in      nd: sys_int_machine_t;       {min number of significant digits}
  in      unit: string);               {units label, Pascal string}
  val_param;

var
  n: string_var32_t;                   {the base number without units}
  u: string_var4_t;                    {name for power of 1000 applied}

begin
  n.max := size_char(n.str);           {init local var strings}
  u.max := size_char(u.str);

  string_f_fp_eng (                    {make number and 1000 mult strings}
    n,                                 {the returned raw number string}
    fp,                                {input value}
    nd,                                {number of significant digits}
    u);                                {1000 multiplier name}

  write (n.str:n.len, ' ', u.str:u.len);
  string_vstring (u, unit, sizeof(unit)); {make UNIT var string}
  if u.len > 0 then begin
    write (u.str:u.len);
    end;
  end;
{
********************************************************************************
*
*   Subroutine WFP (FP, ND)
*
*   Write the floating point value FP with ND digits right of the decimal point.
}
procedure wfp (                        {write floating point value}
  in      fp: real;                    {the floating point value to write}
  in      nd: sys_int_machine_t);      {number of digits right of decimal point}
  val_param;

var
  tk: string_var32_t;                  {output string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_fixed (                  {make fixed point string}
    tk,                                {output string}
    fp,                                {input value}
    nd);                               {digits right of decimal point}
  write (tk.str:tk.len);               {write the string to the output}
  end;
