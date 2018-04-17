{   Module of routines for writing to an HTML output file.
}
module htm_out;
define htm_close_write;
define htm_open_write_name;
define htm_write_buf;
define htm_write_indent;
define htm_write_indent_abs;
define htm_write_indent_rel;
define htm_write_undent;
define htm_write_line;
define htm_write_line_str;
define htm_write_str;
define htm_write_vstr;
define htm_write_nopad;
define htm_write_bline;
define htm_write_pre_start;
define htm_write_pre_line;
define htm_write_pre_end;
define htm_write_newline;
define htm_write_color;
define htm_write_color_gray;
define htm_write_wrap;
%include 'stuff2.ins.pas';
{
********************************************************************************
*
*   Subroutine HTM_CLOSE_WRITE (HOUT, STAT)
*
*   Close an HTML output file that is open for writing.  HOUT is the private
*   state for this HTML output connection.
}
procedure htm_close_write (            {close HTML file open for writing}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_buf (hout, stat);          {write all buffered data, if any, to file}
  if sys_error(stat) then return;

  file_close (hout.conn);              {close the connection to the output file}
  end;
{
********************************************************************************
*
*   Subroutine HTM_OPEN_WRITE_NAME (HOUT, FNAM, STAT)
*
*   Open an HTML file for writing.  The file is created if it does not already
*   exist.  The ".htm" file name suffix is automatically appended unless FNAM
*   already ends in ".htm" or ".html".
}
procedure htm_open_write_name (        {open/create HTML output file by name}
  out     hout: htm_out_t;             {returned initialized HTM writing state}
  in      fnam: univ string_var_arg_t; {pathname of file to open or create}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  file_open_write_text (               {open HTML file for writing text to it}
    fnam, '.htm .html',                {file name and list of valid suffixes}
    hout.conn,                         {returned connection to file}
    stat);
  if sys_error(stat) then return;
{
*   File has been opened successfully.  Now initialize the private connection
*   state.
}
  hout.buf.max := size_char(hout.buf.str); {init to no unwritted buffered data}
  hout.buf.len := 0;
  hout.indent_lev := 0;                {init indentation level}
  hout.indent_size := 2;               {init characters per indentation level}
  hout.indent := hout.indent_lev * hout.indent_size; {init char of indentation}
  hout.pad := true;                    {init to write separator before next token}
  hout.wrap := true;                   {init to allow wrapping to next line at blank}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_BUF (HOUT, STAT)
*
*   Write all locally buffered output data, if any, to the output file.
}
procedure htm_write_buf (              {write all buffered data, if any, to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  if hout.buf.len <= 0 then begin      {there is no buffered unwritten data ?}
    sys_error_none (stat);
    return;
    end;

  file_write_text (hout.buf, hout.conn, stat); {write the buffered data}
  if sys_error(stat) then return;

  hout.buf.len := 0;                   {reset to no buffered data exists}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_NEWLINE (HOUT, STAT)
*
*   Force subsequent data to be written to a new output line.
}
procedure htm_write_newline (          {new data goes to new line of HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_buf (hout, stat);
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_INDENT (HOUT)
*
*   Increase the indentation level for new lines by one level.
}
procedure htm_write_indent (           {indent HTM writing by one level}
  in out  hout: htm_out_t);            {state for writing to HTML output file}
  val_param;

begin
  htm_write_indent_rel (hout, 1);
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_INDENT_ABS (HOUT, INDABS)
*
*   Set the new output writing indentation level to an absolute value.  The
*   indentation level of 0 indicates to write at the left margin, with higher
*   values indicating successively more indentation.  Negative indentation
*   levels are not allowed.
}
procedure htm_write_indent_abs (       {set HTM absolute output indentation level}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      indabs: sys_int_machine_t);  {new absolute indentation level}
  val_param;

begin
  htm_write_indent_rel (hout, indabs - hout.indent_lev);
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_INDENT_REL (HOUT, INDREL)
*
*   Set the new output writing indentation level relative to the current
*   indentation level.  Zero causes no change, with positive values causing
*   increasing indentation and negative value less indentation.  Absolute
*   indentation levels below zero will be clipped at zero.
}
procedure htm_write_indent_rel (       {set HTM relative output indentation level}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      indrel: sys_int_machine_t);  {additional levels to indent, may be neg}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer}

begin
  i := max(-hout.indent_lev, indrel);  {make clipped indentation level change}
  hout.indent := max(0, hout.indent + i * hout.indent_size); {num of indent chars}
  hout.indent_lev := hout.indent_lev + i; {update indentation level}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_UNDENT (HOUT)
*
*   Decrease the indentation level for new lines by one level.
}
procedure htm_write_undent (           {un-indent HTM writing by one level}
  in out  hout: htm_out_t);            {state for writing to HTML output file}
  val_param;

begin
  htm_write_indent_rel (hout, -1);
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_LINE (HOUT, LINE, STAT)
*
*   Write the text line in LINE verbatim to the HTML output file.  The text
*   in LINE will be written to the output file on its own line, exactly
*   as passed in LINE.  No indentation will be added or other modifications
*   made.
}
procedure htm_write_line (             {write complete text line to HTM output file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      line: univ string_var_arg_t; {line to write, will be HTM line exactly}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_buf (hout, stat);          {make sure all previous data is written}
  if sys_error(stat) then return;

  file_write_text (line, hout.conn, stat); {write the raw text line as passed}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_LINE_STR (HOUT, LINE, STAT)
*
*   Just like HTM_WRITE_LINE except that LINE is an ordinary string instead of a
*   var string.  If the text to write is less than the 80 characters of LINE, then
*   LINE must be NULL terminated or blank padded.  If blank padded, the trailing
*   blanks are not written to the output file.
}
procedure htm_write_line_str (         {write complete text line to HTM output file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      line: string;                {line to write, NULL term or blank padded}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  vline: string_var80_t;               {temp var string version of LINE}

begin
  vline.max := size_char(vline.str);   {init local var string}

  string_vstring (vline, line, 80);    {make var string from the input argument}
  htm_write_line (hout, vline, stat);  {write the var string to the output file as a line}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_STR (HOUT, STR, STAT)
*
*   Write a free format string to the HTML output file.  This routine just
*   reformats the string and passes it on to HTM_WRITE_VSTR.  See HTM_WRITE_VSTR
*   for symantic details.  STR must be either NULL terminated or padded with
*   blanks up to its maximum length of 80 characters.
}
procedure htm_write_str (              {write free format string to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      str: string;                 {string to write, NULL term or blank padded}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  vstr: string_var80_t;                {temp var string version of STR}

begin
  vstr.max := size_char(vstr.str);     {init local var string}

  string_vstring (vstr, str, 80);      {convert string to var string}
  htm_write_vstr (hout, vstr, stat);   {pass vstring to routine to do the real work}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_VSTR (HOUT, STR, STAT)
*
*   Write a free format string to the HTML output file.
*
*   If wrapping is enabled, the string may be wrapped to multiple lines at
*   breaks, and may be merged with previous and/or successive free format
*   strings.  Any new lines created will start with leading blanks according to
*   the current indentation setting.  An additional HTML hard space will be
*   added after end of sentence punctuation.
*
*   If wrapping is disabled, the string is appended as-is to the current output
*   line.  No hard space will be inserted after end of sentence punctuation.
}
procedure htm_write_vstr (             {write free format string to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      str: univ string_var_arg_t;  {string to write}
  out     stat: sys_err_t);            {completion status code}
  val_param;

const
  maxlen = 80;                         {max output line length if possible}

var
  i: sys_int_machine_t;                {scratch integer and loop counter}
  delim_pick: sys_int_machine_t;       {index of delimiter that ended token}
  tk: string_var8192_t;                {scratch token}
  p: string_index_t;                   {parse index}

label
  loop_tk, add_tk, first_tk;

begin
  tk.max := size_char(tk.str);         {init local var string}
  sys_error_none(stat);                {init to no errors occurred}

  p := 1;                              {init input line parse index}
loop_tk:                               {back here each new token from the input str}
  if p > str.len then return;          {input string has been exhausted ?}
  if hout.wrap
    then begin                         {wrapping is enabled}
      string_token_anyd (              {extract next input line token}
        str,                           {input string}
        p,                             {parse index}
        ' ', 1, 1,                     {delimiters, N delimiters, N repeatable}
        [],                            {option flags}
        tk,                            {returned token parsed from STR}
        delim_pick,                    {delimiter index that ended token, unused}
        stat);
      if string_eos(stat) then return; {exhausted input string ?}
      if tk.len <= 0 then goto loop_tk; {ignore empty tokens}
      case tk.str[tk.len] of           {what is last character of token ?}
'.', '!', '?': begin                   {end of sentence punctuation}
          string_appends (tk, '&nbsp;'(0)); {add hard space to end of token}
          end;
        end;                           {end of token ending character cases}
      end
    else begin                         {wrapping is disabled}
      string_copy (str, tk);           {treat the whole input string as one token}
      p := str.len + 1;                {indicate the input string has been exhausted}
      end
    ;

  if hout.buf.len <= 0 then goto first_tk; {no previous line, first tk on new line ?}
{
*   A partial output line was built previously.  Append the new token to
*   the end of that line if it fits.
}
  i := 1;                              {init separator size before this token}
  if not hout.pad then i := 0;         {no separator before this token ?}
  if
      (hout.buf.len + i + tk.len) > maxlen {line would be too long with new token ?}
      then begin
    htm_write_buf (hout, stat);        {write old line to file, clear output buffer}
    if sys_error(stat) then return;
    goto first_tk;                     {token will now be first on new line}
    end;

  if hout.pad then begin
    string_append1 (hout.buf, ' ');    {add separator before new token}
    end;
{
*   Unconditionally add the token to the end of the current output line.
*   A separator before previous line content, if any, must already be written
*   to BUF.
}
add_tk:
  string_append (hout.buf, tk);        {add token to end of current line}
  hout.pad := true;                    {reset to add separator after this token}
  goto loop_tk;                        {back to do next token in input string}
{
*   The current output line buffer is empty.  The token in TK will be the
*   first token on a new line.
}
first_tk:
  for i := 1 to hout.indent do begin   {once for each indentation character}
    string_append1 (hout.buf, ' ');    {add one indentation character}
    end;
  goto add_tk;                         {add token directly after indent characters}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_NOPAD (HOUT)
*
*   This routine causes the next free format token to be written to the
*   free format output stream without a preceeding separator.  Normally a
*   free format token is preceeded with a blank unless it is the first token
*   on a line.  The flag is automatically reset to cause a separator be
*   written after each free format token is written to the output stream.
*   This routine therefore effects only the next free format token.
*   Subsequent tokens will be preceeded with separators unless this routine
*   is called before each one.
}
procedure htm_write_nopad (            {inhibit blank before next free format token}
  in out  hout: htm_out_t);            {state for writing to HTML output file}
  val_param;

begin
  hout.pad := false;
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_BLINE (HOUT, STAT)
*
*   Write a blank line to the output file.  Any previous buffered unwritten
*   data is written before the blank line.
}
procedure htm_write_bline (            {write blank line to HTML output file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_buf (hout, stat);          {write all previously buffered data, if any}
  if sys_error(stat) then return;

  file_write_text (hout.buf, hout.conn, stat); {write the blank line}
  if sys_error(stat) then return;
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_PRE_START (HOUT, STAT)
*
*   Set up for writing pre-formatted text.  HTM_WRITE_PRE_LINE can be used
*   after this call to write text exactly as it is supposed to appear in the
*   HTML document.  This routine will write the HTML <PRE> tag.
}
procedure htm_write_pre_start (        {start writing pre-formatted text}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_buf (hout, stat);          {write out any previous line}
  if sys_error(stat) then return;

  htm_write_str (hout, '<pre>'(0), stat); {write tag to enter pre-formatted mode}
  if sys_error(stat) then return;
  htm_write_buf (hout, stat)           {close the line after tag to start pre-form}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_PRE_LINE (HOUT, LINE, STAT)
*
*   Write the string to the output file so that it will appear exactly as
*   in LINE.  LINE may contain sequences that form HTML commands.
*   These sequences will be edited so that they are presented to the user
*   verbatim, and will not be interpreted as HTML commands.
*
*   This routine differs from HTM_WRITE_LINE in that HTM_WRITE_LINE writes
*   the line verbatim to the output while, whereas this routine writes the
*   line to the output file such that it is presented verbatim in the resulting
*   document.  The following substitutions will be made from LINE to the
*   string written to the output file:
*
*     "&"  -->  "&amp;"
*     "<"  -->  "&lt;"
*     ">"  -->  "&gt;"
*
*   It will be assumed that pre-formatted text mode has been started but not
*   yet ended.
}
procedure htm_write_pre_line (         {write one line of pre-formatted text}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      line: univ string_var_arg_t; {line to write, HTM control chars converted}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}
  buf: string_var8192_t;               {one line output buffer}

begin
  buf.max := size_char(buf.str);       {init local var string}

  buf.len := 0;                        {init output line buffer to empty}
  for i := 1 to line.len do begin      {once for each character in LINE}
    case line.str[i] of                {check for special characters}
'&':  begin
        string_appends (buf, '&amp;'(0));
        end;
'<':  begin
        string_appends (buf, '&lt;'(0));
        end;
'>':  begin
        string_appends (buf, '&gt;'(0));
        end;
otherwise                              {this char requires no special handling}
      string_append1 (buf, line.str[i]);
      end;
    end;                               {back to do next input line character}

  htm_write_line (hout, buf, stat);    {write translated line to the output file}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_PRE_END (HOUT, STAT)
*
*   End writing pre-formatted text to the output file.  This routine undoes
*   what HTM_WRITE_PRE_START does.
}
procedure htm_write_pre_end (          {stop writing pre-formatted text}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_buf (hout, stat);          {write out any previous line}
  if sys_error(stat) then return;

  htm_write_str (hout, '</pre>'(0), stat); {write tag to exit pre-formatted mode}
  if sys_error(stat) then return;
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_COLOR (HOUT, RED, GRN, BLU, STAT)
*
*   Write a color value in HTML format, which is "#rrggbb", where RR, GG, and BB
*   are color component values expressed as two digit hexadecimal numbers.  The
*   range of each color component is therefore 00-FF, which is 0-255 in decimal.
*   The color to write is given in RED, GRN, and BLU.  Each of these color
*   component values are in 0.0-1.0 floating point format.
*
*   The color specifier string is written in free format without a preceeding
*   blank.
}
procedure htm_write_color (            {write a color value in HTML format, no blank before}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      red, grn, blu: real;         {color components in 0-1 scale}
  out     stat: sys_err_t);            {completion status code}
  val_param;

var
  s: string_var32_t;                   {color specifier string}
  tk: string_var32_t;                  {color component token}

begin
  s.max := size_char(s.str);           {init local var strings}
  tk.max := size_char(tk.str);

  string_vstring (s, '#', 1);          {init color specifier string}

  string_f_int8h (tk, trunc(max(0.0, min(0.999, red)) * 256.0));
  string_append (s, tk);
  string_f_int8h (tk, trunc(max(0.0, min(0.999, grn)) * 256.0));
  string_append (s, tk);
  string_f_int8h (tk, trunc(max(0.0, min(0.999, blu)) * 256.0));
  string_append (s, tk);

  htm_write_nopad (hout);              {inhibit space before next string}
  htm_write_vstr (hout, s, stat);      {write the color specifier to the HTML stream}
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_COLOR_GRAY (HOUT, GRAY, STAT)
*
*   Same as HTM_WRITE_COLOR except that the color is always a level of gray.
*   GRAY is 0.0 to 1.0 floating point, which maps to black to white.
}
procedure htm_write_color_gray (       {write gray color value in HTML format, no blank before}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      gray: real;                  {0-1 gray value}
  out     stat: sys_err_t);            {completion status code}
  val_param;

begin
  htm_write_color (hout, gray, gray, gray, stat);
  end;
{
********************************************************************************
*
*   Subroutine HTM_WRITE_WRAP (HOUT, ONOFF)
*
*   Sets whether future strings are allowed to be wrapped to the next line at
*   blanks.  ONOFF of TRUE allows wrapping, and FALSE disallows it.  Wrapping is
*   enabled when the HTML file writing state is first created.
}
procedure htm_write_wrap (             {set wrapping to new lines a blanks}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      onoff: boolean);             {TRUE enables wrapping, FALSE disables}
  val_param;

begin
  hout.wrap := onoff;
  end;
