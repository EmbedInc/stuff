{   Routines that read and decode quoted printable encoded text.
}
module qprint_read;
define qprint_read_char_str;
define qprint_read_open_conn;
define qprint_read_getline;
define qprint_read_char;
define qprint_read_close;
%include '(cog)dsee_libs/progs/stuff2.ins.pas';

const
  cr = 13;                             {carriage return character code}
  lf = 10;                             {line feed character code}
{
************************************************************************
*
*   Subroutine QPRINT_READ_CHAR_STR (BUF, P, SINGLE, C, STAT)
*
*   This routine performs the actual translation from quoted printable to
*   direct character representation.  BUF contains a string in quoted
*   printable format.  P is the parse index and indicates the next
*   character position in BUF to be read.  C is the returned decoded
*   character.  STAT is the completion status.  Other than hard errors,
*   it will be set to STRING_STAT_EOS_K when the input string has been
*   exhausted.
*
*   BUF must not contain any trailing spaces.  The results are undefined
*   if it does.
}
procedure qprint_read_char_str (       {decode quoted printable char from string}
  in      buf: univ string_var_arg_t;  {qprint input string, no trailing blanks}
  in out  p: string_index_t;           {parse index, init to 1 for start of string}
  in      single: boolean;             {single string, not in succession of lines}
  out     c: char;                     {returned decoded character}
  out     stat: sys_err_t);            {completion status, EOS on input string end}
  val_param;

type
  st_t = (                             {parsing states}
    st_norm_k,                         {normal, expecting literal character}
    st_h1_k,                           {expecting first hexadecimal digit}
    st_h2_k);                          {expecting second hexadecimal digit}

var
  st: st_t;                            {parsing state}
  cc: char;                            {last char read from input string}
  hex: string_var4_t;                  {hexadecimal string}
  hval: sys_int_max_t;                 {integer value of hexadecimal string}

label
  loop, eos;

begin
  hex.max := size_char(hex.str);       {init local var string}
  sys_error_none (stat);               {init to no exception condition encountered}

  st := st_norm_k;                     {init to expecting literal character}

loop:                                  {back here each new char from input string}
  if p > buf.len then begin            {exhausted input line ?}
    if not single then begin           {input whole line, not just a single string}
      if p = (buf.len + 1) then begin  {at CR of implied CRLF ?}
        c := chr(cr);                  {return the CR}
        p := p + 1;
        return;
        end;
      if p = (buf.len + 2) then begin  {at LF of implied CRLF ?}
        c := chr(lf);                  {return the LF}
        p := p + 1;
        return;
        end;
      end;                             {done handling implied CRLF at end of line}
eos:                                   {jump here to return indicating end of string}
    sys_stat_set (string_subsys_k, string_stat_eos_k, stat); {end of string status}
    return;
    end;
  cc := buf.str[p];                    {get this input character}
  p := p + 1;                          {advance parse index to next input char}

  case st of                           {what is the parsing state ?}
{
*   Expecting normal literal character.
}
st_norm_k: begin
      if cc <> '=' then begin          {literal character, not special case ?}
        c := cc;                       {pass back the literal character}
        return;
        end;
      {
      *   Character is "=".
      }
      if p > buf.len then begin        {no implied CRLF at the end of this line ?}
        p := buf.len + 3;              {indicate no CRLF to send at end of line}
        goto eos;                      {return with end of string status}
        end;
      st := st_h1_k;                   {next char is first hex digit of char code}
      hex.len := 0;                    {init hexadecimal string to empty}
      end;
{
*   First hexadecimal character of character code.
}
st_h1_k: begin
      string_append1 (hex, cc);        {add this char to end of hex string}
      st := st_h2_k;                   {next char is second hex digit of char code}
      end;
{
*   Second hexadecimal character of character code.
}
st_h2_k: begin
      string_append1 (hex, cc);        {add this char to end of hex string}
      string_t_int_max_base (          {convert hex string to its integer value}
        hex,                           {input string}
        16,                            {radix}
        [string_ti_unsig_k],           {resulting number is unsigned}
        hval,                          {returned integer value}
        stat);
      if sys_error(stat) then return;  {hard error ?}
      c := chr(hval);                  {return the resulting character}
      return;
      end;                             {end of second hex char parsing case}

    end;                               {end of parsing state cases}
  goto loop;                           {back to process next encoded input character}
  end;
{
************************************************************************
*
*   Subroutine QPRINT_READ_OPEN_CONN (QPRINT, CONN, STAT)
*
*   Set up for reading decoded text from a quoted printable input stream.
*   QPRINT is the quoted printable reading state, and will be initialized
*   by this call.  System resources may be allocated until QPRINT_READ_CLOSE
*   is called with the same QPRINT.  CONN is the connection to the
*   quoted printable input stream.  This must be a text stream.
}
procedure qprint_read_open_conn (      {set up for reading quoted printable stream}
  out     qprint: qprint_read_t;       {reading state, will be initialized}
  in out  conn: file_conn_t;           {connection to quoted printable input stream}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no errors encountered}

  qprint.buf.max := size_char(qprint.buf.str); {init one line input buffer}
  qprint.buf.len := 0;                 {init to no buffered characters available}
  qprint.p := 3;                       {completely finished with string in BUF}
  qprint.flags := [];
  qprint.conn_p := addr(conn);         {save pointer to input stream connection}
  end;
{
************************************************************************
*
*   Subroutine QPRINT_READ_GETLINE (QPRINT, STAT)
*
*   Abort the current input line, if any, and read the next input line from
*   the input stream.  The input line will be read into BUF and the parse
*   index reset so that the first character of the new line is parsed next.
*   EOF status is returned when the end of the input stream is encountered.
}
procedure qprint_read_getline (        {abort this input line, get next}
  in out  qprint: qprint_read_t;       {reading state, returned invalid}
  out     stat: sys_err_t);            {completion status, can be EOF}
  val_param;

begin
  file_read_text (qprint.conn_p^, qprint.buf, stat); {read next input stream line}
  if sys_error(stat) then return;
  string_unpad (qprint.buf);           {strip trailing blanks from input line}
  qprint.p := 1;                       {init parse index for this input line}
  end;
{
************************************************************************
*
*   Subroutine QPRINT_READ_CHAR (QPRINT, C, STAT)
*
*   Return the next plain text character decoded from the quoted printable
*   input stream identified by QPRINT.  The character is returned in C.
}
procedure qprint_read_char (           {decode next char from quoted printable strm}
  in out  qprint: qprint_read_t;       {state for reading quoted printable stream}
  out     c: char;                     {next character decoded from the stream}
  out     stat: sys_err_t);            {completion status}
  val_param;

label
  loop, got_char;

begin
loop:                                  {back here each new attempt to get char}
  if qprflag_passthru_k in qprint.flags
    then begin                         {pass input stream thru, no interpret ?}
      if qprint.p <= qprint.buf.len then begin {real buffer character ?}
        c := qprint.buf.str[qprint.p]; {get the character}
        qprint.p := qprint.p + 1;      {advance parse index}
        goto got_char;
        end;
      if qprint.p = (qprint.buf.len + 1) then begin {pass back CR ?}
        c := chr(cr);
        qprint.p := qprint.p + 1;      {advance parse index}
        goto got_char;
        end;
      if qprint.p = (qprint.buf.len + 2) then begin {pass back LF ?}
        c := chr(lf);
        qprint.p := qprint.p + 1;      {advance parse index}
        goto got_char;
        end;
      sys_stat_set (string_subsys_k, string_stat_eos_k, stat); {end of string}
      end
    else begin                         {perform quoted printable interpretation}
      qprint_read_char_str (           {decode char from the input buffer}
        qprint.buf, qprint.p, false, c, stat);
      end
    ;
got_char:

  if string_eos(stat) then begin       {hit end of this input string ?}
    qprint_read_getline (qprint, stat); {read next input line into BUF}
    if sys_error(stat) then return;
    goto loop;                         {back to try reading decoded character again}
    end;
  end;
{
************************************************************************
*
*   Subroutine QPRINT_READ_CLOSE (QPRINT, STAT)
*
*   End reading and decoding a quoted printable stream, and deallocate any
*   system resources used for that purpose.  QPRINT is the quoted printable
*   reading state, and will be returned invalid.
}
procedure qprint_read_close (          {deallocate resources for reading quoted print}
  in out  qprint: qprint_read_t;       {reading state, returned invalid}
  out     stat: sys_err_t);            {completion status}
  val_param;

begin
  sys_error_none (stat);               {init to no errors encountered}

  if qprflag_conn_close_k in qprint.flags then begin {close the input stream ?}
    file_close (qprint.conn_p^);       {close the underlying input stream}
    if qprflag_conn_del_k in qprint.flags then begin {delete input connection ?}
      sys_mem_dealloc (qprint.conn_p); {deallocate connection descriptor}
      end;
    end;

  qprint.conn_p := nil;                {indicate no input stream association}
  end;
