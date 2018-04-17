{   Routines for dealing with Intel HEX files.
}
module ihex;
define ihex_in_open_conn;
define ihex_in_open_fnam;
define ihex_in_close;
define ihex_in_line_raw;
define ihex_in_dat;
%include 'stuff2.ins.pas';
{
********************************************************************************
*
*   Local subroutine ERR_ATLINE (IHN, STAT)
*
*   Fill in the next two STAT parameters with the current input file line number
*   and the input file name.
}
procedure err_atline (                 {add LNUM and FNAM parameters to STAT}
  in      ihn: ihex_in_t;              {HEX file reading state}
  in out  stat: sys_err_t);            {will have LNUM and FNAM parameters added}
  val_param; internal;

begin
  sys_stat_parm_int (ihn.conn_p^.lnum, stat);
  sys_stat_parm_vstr (ihn.conn_p^.tnam, stat);
  end;
{
********************************************************************************
*
*   Local subroutine ERR_SHOWCHAR (IHN, CI, STAT)
*
*   Add parameters to STAT to indicate a particular character.  Two parameters
*   will be added to stat.  The first will be the source line in IHN.IBUF.  The
*   second will be 0 or more blanks followed by a single up arrow that will
*   point to the IBUF character at index CI.
}
procedure err_showchar (               {add source line and pointer parms to STAT}
  in      ihn: ihex_in_t;              {HEX file reading state}
  in      ci: string_index_t;          {1-N index of character within LINE}
  in out  stat: sys_err_t);            {will have two parameters added}
  val_param; internal;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}
  up: string_var1024_t;                {string with blanks an up arrow}

begin
  up.max := size_char(up.str);         {init local var string}

  sys_stat_parm_vstr (ihn.ibuf, stat); {add source line as parameter}

  up.len := 0;
  for i := 2 to ci do begin            {once for each blank before up arrow}
    string_append1 (up, ' ');
    end;
  string_append1 (up, '^');
  sys_stat_parm_vstr (up, stat);       {add line with arrow pointing to char}
  end;
{
********************************************************************************
*
*   Local subroutine ERR_ATLINE_SHOWCHAR (IHN, CI, STAT)
*
*   Add four parameters to STAT:
*
*     1  -  Current input file line number.
*     2  -  Input file treename.
*     3  -  The string in IHN.IBUF.
*     4  -  Line with up arrow pointing to character at index CI in LINE.
}
procedure err_atline_showchar (        {add LNUM, FNAM, LINE, char pointer to STAT}
  in      ihn: ihex_in_t;              {HEX file reading state}
  in      ci: string_index_t;          {1-N index of character within LINE}
  in out  stat: sys_err_t);            {will have two parameters added}
  val_param; internal;

begin
  err_atline (ihn, stat);              {add LNUM and FNAM parameters}
  err_showchar (ihn, ci, stat);        {add LINE and pointer to char parameters}
  end;
{
********************************************************************************
*
*   Local subroutine IHEX_IN_INIT (IHN)
*
*   Initialize the state for reading and processing an Intel HEX file text
*   stream.
}
procedure ihex_in_init (               {init state for reading Intel HEX file stream}
  out     ihn: ihex_in_t);             {state to initialize}
  val_param;

begin
  ihn.conn_p := nil;
  ihn.adrbase := 0;
  ihn.ndat := 0;
  ihn.ibuf.max := size_char(ihn.ibuf.str);
  for ihn.ibuf.len := 1 to ihn.ibuf.max do begin {init to NULLs for easier debug}
    ihn.ibuf.str[ihn.ibuf.len] := chr(0);
    end;
  ihn.ibuf.len := 0;
  ihn.p := 1;
  ihn.cksum := 0;
  ihn.flags := [];
  end;
{
********************************************************************************
*
*   Subroutine IHEX_IN_OPEN_CONN (CONN, IHN, STAT)
*
*   Open a new use of the IHEX_IN routines with an existing text input stream.
*   These routines read and process an Intel HEX file text stream.
}
procedure ihex_in_open_conn (          {open HEX in routines with existing stream}
  in out  conn: file_conn_t;           {connection to the input stream}
  out     ihn: ihex_in_t;              {returned state for this IHEX input stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no error occurred}
  ihex_in_init (ihn);                  {init internal state}

  ihn.conn_p := addr(conn);            {save pointer to input stream connection}
  end;
{
********************************************************************************
*
*   Subroutine IHEX_IN_OPEN_FNAM (FNAM, EXT, IHN, STAT)
*
*   Open a new use of the IHEX_IN routines with a file name.
}
procedure ihex_in_open_fnam (          {open HEX in routines with file name}
  in      fnam: univ string_var_arg_t; {file name}
  in      ext: string;                 {file name suffix}
  out     ihn: ihex_in_t;              {returned state for this IHEX input stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

label
  err;

begin
  ihex_in_init (ihn);                  {init internal state}
  sys_mem_alloc (sizeof(ihn.conn_p^), ihn.conn_p); {allocate connection descriptor}

  file_open_read_text (                {open HEX file for text read}
    fnam, ext,                         {file name and suffix}
    ihn.conn_p^,                       {returned connection to the file}
    stat);
  if sys_error(stat) then goto err;

  ihn.flags := ihn.flags + [ihn_flag_ownconn_k]; {indicate we own connection desc}
  return;

err:                                   {error occurred, stat already set}
  sys_mem_dealloc (ihn.conn_p);        {deallocate connection descriptor memory}
  ihn.conn_p := nil;
  end;
{
********************************************************************************
*
*   Subroutine IHEX_IN_CLOSE (IHN, STAT)
*
*   Close this a use of the IHEX_IN routines.
}
procedure ihex_in_close (              {close a use of the IHEX_IN routines}
  in out  ihn: ihex_in_t;              {state this use of routines, returned invalid}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

begin
  sys_error_none (stat);

  if ihn_flag_ownconn_k in ihn.flags then begin {we own the connection descriptor ?}
    file_close (ihn.conn_p^);          {close connection to the input stream}
    sys_mem_dealloc (ihn.conn_p);      {deallocate connection descriptor memory}
    end;

  ihn.conn_p := nil;                   {set state to invalid}
  end;
{
********************************************************************************
*
*   Local subroutine IHEX_IN_GET_LINE (IHN, STAT)
*
*   Get the next Intel HEX file line from the input stream and set up the state
*   in IHN accordingly.  Lines that don't start with the mandatory ":" are
*   skipped over as if they were comment lines.
}
procedure ihex_in_get_line (           {get next input line and set up state}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;


begin
  if ihn_flag_eof_k in ihn.flags then begin {HEX EOF record was previously read ?}
    sys_stat_set (file_subsys_k, file_stat_eof_k, stat); {return end of file status}
    return;
    end;

  while true do begin                  {loop until get line starting with ":"}
    file_read_text (ihn.conn_p^, ihn.ibuf, stat); {try to read next line from file}
    if sys_error(stat) then begin      {other than got line normally ?}
      if file_eof(stat) then begin     {hit physical end of the input file ?}
        sys_stat_set (                 {end of file before HEX EOF record}
          stuff_subsys_k, stuff_stat_ihex_eof_k, stat);
        end;
      return;                          {return with error}
      end;

    string_unpad (ihn.ibuf);           {truncate trailing spaces}
    if ihn.ibuf.len <= 0 then next;    {ignore blank lines}
    if ihn.ibuf.str[1] <> ':' then next; {not start with colon, assume comment ?}
    exit;                              {got a real line}
    end;

  ihn.p := 2;                          {start reading right after colon}
  ihn.cksum := 0;                      {init checksum for this new line}
  end;
{
********************************************************************************
*
*   Local function IHEX_IN_HEXD (IHN, STAT)
*
*   Read the next input line character, interpret it as a HEX digit, and return
*   its 0-15 value.
}
function ihex_in_hexd (                {get value of next char as hex digit}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     stat: sys_err_t)             {returned completion status code}
  :int32u_t;
  val_param; internal;

var
  c: char;                             {character read from the input line}

label
  retry;

begin
  ihex_in_hexd := 0;                   {prevent compiler uninitialized warning}

retry:                                 {back here to skip curr char and try next}
  if ihn.p > ihn.ibuf.len then begin   {there is no character to read ?}
    sys_stat_set (stuff_subsys_k, stuff_stat_ihex_eos_k, stat);
    err_atline (ihn, stat);
    return;
    end;

  c := string_upcase_char(ihn.ibuf.str[ihn.p]); {fetch input character in upper case}
  ihn.p := ihn.p + 1;                  {advance the input line parse index}
  if c = ' ' then goto retry;          {ignore blanks}
  if (c >= '0') and (c <= '9') then begin {character is 0 - 9 ?}
    ihex_in_hexd := ord(c) - ord('0'); {pass back hex digit value}
    return;
    end;
  if (c >= 'A') and (c <= 'F') then begin {character is A - F ?}
    ihex_in_hexd := ord(c) - ord('A') + 10; {pass back hex digit value}
    return;
    end;

  sys_stat_set (stuff_subsys_k, stuff_stat_ihex_badchar_k, stat);
  err_atline_showchar (ihn, ihn.p - 1, stat);
  end;
{
********************************************************************************
*
*   Local function IHEX_IN_HEX8 (IHN, STAT)
*
*   Read the next two input line characters, interpret them a HEX byte, and
*   return the 0-255 byte value.  The checksum is updated to include the new
*   byte read.
}
function ihex_in_hex8 (                {get value of next two chars as HEX byte}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     stat: sys_err_t)             {returned completion status code}
  :int8u_t;
  val_param; internal;

var
  i: int32u_t;                         {assembled byte value}

begin
  ihex_in_hex8 := 0;                   {prevent compiler uninitialized warning}

  i := lshft(ihex_in_hexd(ihn, stat), 4); {get most significant digit}
  if sys_error(stat) then return;
  i := i ! ihex_in_hexd(ihn, stat);    {merge in least significant digit}

  ihn.cksum := ihn.cksum + i;          {update the checksum with the new byte}
  ihex_in_hex8 := i;                   {return the byte value}
  end;
{
********************************************************************************
*
*   Local function IHEX_IN_HEX16 (IHN, STAT)
*
*   Read the next four input line characters, interpret them as HEX digits, and
*   return their 16 bit value.  The checksum is updated with the two byte values
*   read from the input line.
}
function ihex_in_hex16 (               {get 16 bit val from next four chars}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     stat: sys_err_t)             {returned completion status code}
  :int16u_t;
  val_param; internal;

var
  i: int32u_t;                         {assembled byte value}

begin
  ihex_in_hex16 := 0;                  {prevent compiler uninitialized warning}

  i := lshft(ihex_in_hex8(ihn, stat), 8); {get most significant byte}
  if sys_error(stat) then return;
  i := i ! ihex_in_hex8(ihn, stat);    {merge in least significant byte}
  ihex_in_hex16 := i;                  {pass back result}
  end;
{
********************************************************************************
*
*   Local function IHEX_IN_DAT_I (ND, DAT)
*
*   Interpret the data bytes in the DAT array as one integer value.  The most
*   significant byte is at index 0, and the least significant at index ND.
}
function ihex_in_dat_i (               {make integer value from data bytes}
  in      nd: sys_int_machine_t;       {number of bytes in DAT}
  in      dat: ihex_dat_t)             {the data bytes}
  :int32u_t;
  val_param; internal;

var
  i: sys_int_machine_t;                {loop counter}
  ival: int32u_t;                      {assembled integer value}

begin
  ival := 0;                           {init the assembled integer value to zero}
  for i := 0 to nd-1 do begin          {once for each data byte}
    ival := lshft(ival, 8);            {make room for new byte in least sig position}
    ival := ival ! dat[i];             {merge in new data byte}
    end;
  ihex_in_dat_i := ival;               {pass back the final result}
  end;
{
********************************************************************************
*
*   Subroutine IHEX_IN_LINE_RAW (IHN, ND, ADR, RTYPE, DAT, STAT)
*
*   Read the next line from an Intel HEX file stream and return its raw info.
}
procedure ihex_in_line_raw (           {read hex file line and return the raw info}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     nd: sys_int_machine_t;       {0-255 number of data bytes}
  out     adr: int32u_t;               {address represented by address field}
  out     rtype: ihex_rtype_k_t;       {record type ID}
  out     dat: ihex_dat_t;             {the data bytes}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}

begin
  ihex_in_get_line (ihn, stat);        {get the next line from the input stream}
  if sys_error(stat) then return;

  nd := ihex_in_hex8 (ihn, stat);      {get number of data bytes on the line}
  if sys_error(stat) then return;

  adr :=                               {get address represented by address field}
    ihex_in_hex16(ihn, stat) + ihn.adrbase;
  if sys_error(stat) then return;

  rtype := ihex_rtype_k_t(ihex_in_hex8(ihn, stat)); {get record type ID}
  if sys_error(stat) then return;

  for i := 0 to nd-1 do begin          {once for each data byte in this record}
    dat[i] := ihex_in_hex8 (ihn, stat); {get this data byte}
    if sys_error(stat) then return;
    end;

  discard( ihex_in_hex8 (ihn, stat) ); {update checksum to include checksum byte}
  if sys_error(stat) then return;
  if ihn.cksum <> 0 then begin         {checksum mismatch ?}
    sys_stat_set (stuff_subsys_k, stuff_stat_ihex_cksum_k, stat);
    err_atline (ihn, stat);
    end;
  end;
{
********************************************************************************
*
*   Subroutine IHEX_IN_DAT (IHN, ADR, ND, DAT, STAT)
*
*   Return the data from the next data record or end of file status if an end of
*   file record is encountered.  Control records are silently processed,
*   although their information may modify the data and address values returned.
}
procedure ihex_in_dat (                {get data bytes from next HEX file data rec}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     adr: int32u_t;               {address of first data byte in DAT}
  out     nd: sys_int_machine_t;       {0-255 number of data bytes in DAT}
  out     dat: ihex_dat_t;             {the data bytes}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  ival: int32u_t;                      {data bytes converted to single integer}
  rtype: ihex_rtype_k_t;               {record type ID}

label
  next_line;

begin
next_line:                             {back here to get another input file line}
  ihex_in_line_raw (ihn, nd, adr, rtype, dat, stat); {get raw info from next line}
  if sys_error(stat) then return;
  case rtype of                        {what type of record is this ?}
{
*   Data record.
}
ihex_rtype_dat_k: begin                {00 data record}
      ihn.ndat := ihn.ndat + nd;       {update total number of data bytes read}
      return;
      end;
{
*   End of file record.
}
ihex_rtype_eof_k: begin                {01 end of file}
      ihn.flags := ihn.flags + [ihn_flag_eof_k]; {remember EOF record found}
      sys_stat_set (file_subsys_k, file_stat_eof_k, stat);
      end;
{
*   Segmented address record.
}
ihex_rtype_segadr_k: begin             {02 segmented address}
      ival := ihex_in_dat_i (nd, dat); {make integer value from the data bytes}
      ihn.adrbase := lshft(ival, 4);   {update base address for future data bytes}
      end;
{
*   Linear address record.
}
ihex_rtype_linadr_k: begin             {04 linear address record}
      ival := ihex_in_dat_i (nd, dat); {make integer value from the data bytes}
      ihn.adrbase := lshft(ival, 16);  {update base address for future data bytes}
      end;
{
*   Unrecognized record type.
}
otherwise
    sys_stat_set (stuff_subsys_k, stuff_stat_ihex_badtype_k, stat);
    sys_stat_parm_int (ord(rtype), stat);
    err_atline (ihn, stat);
    return;
    end;

  goto next_line;                      {done processing this line, back for next}
  end;
