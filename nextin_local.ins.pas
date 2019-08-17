{   This include file defines local routines for reading parameters from a one
*   line input buffer.  These routines are normally used for getting parameters
*   for a command processor.
*
*   The following resources must be defined outside this file:
*
*     LOCKOUT  -  Subroutine that will be called before anything is written to
*       standard output.
*
*     UNLOCKOUT  -  Subroutine that will be called after done writing to
*       standard output.
*
*   All input implicitly comes from INBUF, and P is the string index of the next
*   unread character in INBUF.
*
*   The routines in this file are listed briefly here.  See the header comments
*   of the individual routines for details.
*
*   NEXT_TOKEN (TK, STAT)
*
*     Get the next token into TK.
*
*   NEXT_KEYW (TK, STAT)
*
*     Get the next token as a keyword into TK.  TK will be upper case.
*
*   NEXT_ONOFF (STAT)
*
*     Returns boolean according to ON or OFF keyword.
*
*   NEXT_INT (MN, MX, STAT)
*
*     Returns integer value of next token, MN to MX range.
*
*   NEXT_INT_HEX (MN, MX, STAT)
*
*     Returns integer value of next hexadecimal token, MN to MX range.
*
*   NEXT_HEXSTRING (AR, MAXB, NB, STAT)
*
*     Gets the next token and interprets it as a string of HEX characters
*     representing a sequence of bytes.  The bytes will be written to the
*     array AR, up to MAXB bytes.  NB is returned the actual number of bytes.
*
*   NEXT_IPADR (STAT)
*
*     Returns network IP address represented by next token.  Token can be dot
*     notation IP address or translatable host name.
*
*   NEXT_MACADR (ADR, STAT)
*
*     Returns ethernet MAC address represented by next token.  Example token
*     format is 12-34-56-78-9A-BC.
*
*   NEXT_FP (STAT)
*
*     Returns floating point value of next token.
*
*   NOT_EOS
*
*     Returns TRUE iff INBUF not exhausted.
}
type
  next_bytear_t = array[0..1] of int8u_t; {arbitrary array of bytes}

var
  inbuf:                               {one line command input buffer}
    %include '(cog)lib/string8192.ins.pas';
  p: string_index_t;                   {INBUF parse index}
{
********************************************************************************
*
*   Subroutine NEXT_TOKEN (TK, STAT)
*
*   Get the next token from BUF into TK.
}
procedure next_token (                 {get next token from BUF}
  in out  tk: univ string_var_arg_t;   {returned token}
  out     stat: sys_err_t);
  val_param; internal;

begin
  string_token (inbuf, p, tk, stat);
  end;
{
********************************************************************************
*
*   Subroutine NEXT_KEYW (TK, STAT)
*
*   Parse the next token from BUF as a keyword and return it in TK.
}
procedure next_keyw (
  in out  tk: univ string_var_arg_t;   {returned token}
  out     stat: sys_err_t);
  val_param; internal;

begin
  string_token (inbuf, p, tk, stat);
  string_upcase (tk);
  end;
{
********************************************************************************
*
*   Function NEXT_ONOFF (STAT)
*
*   Parse the next token from BUF and interpret as "ON" or "OFF".  The
*   function value will be TRUE for ON, and FALSE for off.
}
function next_onoff (                  {get next token as integer value}
  out     stat: sys_err_t)             {completion status code}
  :boolean;
  val_param; internal;

var
  tk: string_var16_t;                  {next keyword from BUF}
  t: boolean;                          {interpreted true/false response}

begin
  tk.max := size_char(tk.str);         {init local var string}
  next_onoff := false;                 {init return value to stop C compiler warning}

  next_keyw (tk, stat);                {get next keyword in TK}
  if sys_error(stat) then return;

  string_t_bool (tk, [string_tftype_onoff_k], t, stat); {interpret response into T}
  next_onoff := t;
  end;
{
********************************************************************************
*
*   Function NEXT_INT (MN, MX, STAT)
*
*   Parse the next token from BUF and return its value as an integer.
*   MN and MX are the min/max valid range of the integer value.
}
function next_int (                    {get next token as integer value}
  in      mn, mx: sys_int_machine_t;   {valid min/max range}
  out     stat: sys_err_t)             {completion status code}
  :sys_int_machine_t;
  val_param; internal;

var
  i: sys_int_machine_t;

begin
  string_token_int (inbuf, p, i, stat); {get token value in I}
  next_int := i;                       {pass back value}
  if sys_error(stat) then return;

  if (i < mn) or (i > mx) then begin   {out of range}
    lockout;
    writeln ('Value ', i, ' is out of range.');
    unlockout;
    sys_stat_set (sys_subsys_k, sys_stat_failed_k, stat);
    end;
  end;
{
********************************************************************************
*
*   Function NEXT_INT_HEX (MN, MX, STAT)
*
*   Parse the next token from BUF, interpret it as a HEX integer, and return
*   the result.  MN and MX are the min/max valid range of the integer value.
}
function next_int_hex (                {get next token as HEX integer}
  in      mn, mx: int32u_t;            {valid min/max range}
  out     stat: sys_err_t)             {completion status code}
  :int32u_t;
  val_param; internal;

var
  j: sys_int_max_t;                    {integer value of token}
  i: int32u_t;
  tk: string_var32_t;                  {scratch token}

begin
  tk.max := size_char(tk.str);         {init local var string}
  next_int_hex := 0;                   {disable annoying compiler warning}

  string_token (inbuf, p, tk, stat);   {get the HEX integer string into TK}
  if sys_error(stat) then return;

  string_t_int_max_base (              {convert the string to integer}
    tk,                                {input string}
    16,                                {radix}
    [string_ti_unsig_k],               {HEX value is unsigned}
    j,                                 {output integer}
    stat);
  if sys_error(stat) then return;
  i := j;

  next_int_hex := i;                   {pass back value}
  if sys_error(stat) then return;

  if (i < mn) or (i > mx) then begin   {out of range}
    lockout;
    writeln ('Value ', i, ' is out of range.');
    unlockout;
    sys_stat_set (sys_subsys_k, sys_stat_failed_k, stat);
    end;
  end;
{
********************************************************************************
*
*   Function NEXT_IPADR (STAT)
*
*   Parse the next token as a IP address in dot notation or a machine name
*   and return the resulting 32 bit IP address.
}
function next_ipadr (                  {get next token as IP address}
  out     stat: sys_err_t)             {completion status code}
  :sys_inet_adr_node_t;
  val_param; internal;

var
  tk: string_var256_t;                 {scratch token}
  ipadr: sys_inet_adr_node_t;

begin
  tk.max := size_char(tk.str);         {init local var string}
  next_ipadr := 0;                     {keep compiler from complaining}

  next_token (tk, stat);               {get machine name or dot notation address}
  if sys_error(stat) then return;
  file_inet_name_adr (tk, ipadr, stat); {convert to binary IP address}
  next_ipadr := ipadr;                 {return the result}
  end;
{
********************************************************************************
*
*   Subroutine NEXT_MACADR (ADR, STAT)
*
*   Parse the next token as a ethernet MAC address and return it in ADR.  The
*   format must be hexadecimal bytes separated by dashes.  For example:
*
*     12-34-56-78-9A-BC
}
procedure next_macadr (                {get next token as ethernet MAC address}
  out     adr: sys_macadr_t;           {returned MAC address}
  out     stat: sys_err_t);            {completion status}
  val_param; internal;

var
  ind: sys_int_machine_t;              {0-5 index of MAC address byte}
  ii: sys_int_machine_t;               {scratch integer}
  i32: sys_int_min32_t;                {32 bit integer}
  p: string_index_t;                   {ASTR parse index}
  astr: string_var32_t;                {full MAC address string}
  tk: string_var32_t;                  {scratch token}

begin
  astr.max := size_char(astr.str);     {init local var strings}
  tk.max := size_char(tk.str);

  next_token (astr, stat);             {get the whole address string}
  if sys_error(stat) then return;
  p := 1;                              {init parse index}

  for ind := 5 downto 0 do begin       {once for each byte in high to low order}
    string_token_anyd (                {parse next address byte from string}
      astr,                            {input string}
      p,                               {parse index, updated}
      '-', 1,                          {list of delimeters between tokens}
      0,                               {first N delimeters that may be repeated}
      [],                              {no special options}
      tk,                              {returned parsed token}
      ii,                              {returned index of terminating delimeter}
      stat);
    if sys_error(stat) then return;

    string_t_int32h (tk, i32, stat);   {make value of this address byte}
    if sys_error(stat) then return;

    adr[ind] := i32 & 255;             {set this byte of the MAC address}
    end;
  end;
{
********************************************************************************
*
*   Function NEXT_FP (STAT)
*
*   Parse the next token from BUF and return its value as a floating
*   point number.
}
function next_fp (                     {get next token as floating point value}
  out     stat: sys_err_t)             {completion status code}
  :real;
  val_param; internal;

var
  r: real;

begin
  string_token_fpm (inbuf, p, r, stat);
  next_fp := r;
  end;
{
********************************************************************************
*
*   Function NOT_EOS
*
*   Returns TRUE if the input buffer BUF was is not exhausted.  This is
*   used to check for additional tokens at the end of a command.
}
function not_eos                       {check for more tokens left}
  :boolean;                            {TRUE if more tokens left in BUF}
  val_param; internal;

var
  psave: string_index_t;               {saved copy of BUF parse index}
  tk: string_var4_t;                   {token parsed from BUF}
  stat: sys_err_t;                     {completion status code}

begin
  tk.max := size_char(tk.str);         {init local var string}

  not_eos := false;                    {init to BUF has been exhausted}
  psave := p;                          {save current BUF parse index}
  string_token (inbuf, p, tk, stat);   {try to get another token}
  if sys_error(stat) then return;      {assume normal end of line encountered ?}
  not_eos := true;                     {indicate a token was found}
  p := psave;                          {reset parse index to get this token again}
  end;
{
********************************************************************************
*
*   Subroutine NEXT_HEXSTRING (AR, MAXB, NB, STAT)
*
*   Get the next token and interpret it as a string of HEX characters
*   representing a sequence of bytes.  The bytes will be written to the array
*   AR, up to MAXB bytes.  NB is returned the actual number of bytes found.
*   Error status is returned when there are too many input bytes, the input is
*   not all hexadecimal characters, or the number of hexadecimal characters is
*   odd.
}
procedure next_hexstring (             {read HEX string and return the bytes}
  out     ar: univ next_bytear_t;      {returned array of bytes}
  in      maxb: sys_int_machine_t;     {max bytes to write to AR}
  out     nb: sys_int_machine_t;       {actual number of bytes returned}
  out     stat: sys_err_t);
  val_param; internal;

var
  s: string_var8192_t;                 {HEX string input token}
  tk: string_var32_t;                  {substring of S}
  ind: sys_int_machine_t;              {0-N array index}
  ii, jj: sys_int_machine_t;           {scratch integers}
  hval: sys_int_max_t;                 {converted HEX value}

begin
  s.max := size_char(s.str);           {init local var strings}
  tk.max := size_char(tk.str);
  nb := 0;                             {init not returning with any bytes}

  next_keyw (s, stat);                 {get the next token}
  if sys_error(stat) then return;
  if s.len <= 0 then return;           {no input characters, nothing to do ?}

  if odd(s.len) then begin             {odd number of characters in HEX string}
    sys_stat_set (string_subsys_k, string_stat_nhexb_k, stat);
    return;
    end;
  if s.len > (maxb * 2) then begin     {too many HEX chars for the available bytes ?}
    sys_stat_set (string_subsys_k, string_stat_hexlong_k, stat);
    return;
    end;

  ii := (s.len div 2) - 1;             {last array index to fill in}
  for ind := 0 to ii do begin          {once for each byte}
    jj := (ind * 2) + 1;               {starting HEX string index for this byte}
    string_substr (s, jj, jj+1, tk);   {extract the two HEX characters for this byte}
    string_t_int_max_base (            {convert the two HEX chars to their byte value}
      tk,                              {string to convert}
      16,                              {radix}
      [string_ti_unsig_k],             {the output number is unsigned}
      hval,                            {returned integer value}
      stat);
    if sys_error(stat) then return;    {conversion error ?}
    ar[ind] := hval;                   {stuff this byte into the array}
    nb := nb + 1;                      {count one more byte returned}
    end;
  end;
