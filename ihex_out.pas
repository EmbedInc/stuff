{   Routines for writing to Intel HEX files.
}
module ihex;
define ihex_out_open_conn;
define ihex_out_open_fnam;
define ihex_out_byte;
define ihex_out_close;
%include '/cognivision_links/dsee_libs/progs/stuff2.ins.pas';

const
  maxdat_k = 32;                       {max data bytes allowed on one line}
{
****************************************************************************
*
*   IHEX_OUT_OPEN_CONN (CONN, IHO, STAT)
*
*   Open a use of the HEX file output routines to an existing stream.
*   CONN must be an open text output connection to the stream.  IHO is
*   returned the HEX writing state, which is required for passing to
*   other IHEX_OUT_xxx routines.
}
procedure ihex_out_open_conn (         {open HEX out routines with existing stream}
  in out  conn: file_conn_t;           {connection to the existing output stream}
  out     iho: ihex_out_t;             {returned state for writing to HEX stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no errors encountered}

  iho.conn_p := addr(conn);            {save pointer to text output stream}
  iho.adrbase := 0;                    {init current base address for new lines}
  iho.maxdat := maxdat_k;              {max data bytes allowed on a line}
  iho.adrdat := 0;                     {start address of current line}
  iho.ndat := 0;                       {number of buffered bytes in DAT}
  iho.flags := [];                     {indicate we didn't create text out stream}
  end;
{
****************************************************************************
*
*   IHEX_OUT_OPEN_FNAM (FNAM, EXT, IHO, STAT)
*
*   Open a HEX output file.  FNAM is the base file name, and EXT is the
*   mandatory suffix.  If a file previously exists with this name, then
*   it will be overwritten.  If no such file previously exists, then it
*   will be created.  IHO is returned the HEX file writing state, which
*   is required for passing to other IHEX_OUT_xxx routines.
}
procedure ihex_out_open_fnam (         {open HEX out routines to write to file}
  in      fnam: univ string_var_arg_t; {file name}
  in      ext: string;                 {file name suffix}
  out     iho: ihex_out_t;             {returned state for writing to HEX file}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  conn_p: file_conn_p_t;               {pointer to connection to the new file}
  stat2: sys_err_t;                    {for when STAT already contains error}

label
  abort2, abort;

begin
  sys_mem_alloc (sizeof(conn_p^), conn_p); {allocate memory for new connection desc}
  file_open_write_text (fnam, ext, conn_p^, stat); {open the text output file}
  if sys_error(stat) then goto abort;

  ihex_out_open_conn (conn_p^, iho, stat); {open the IHEX_OUT_xxx library}
  if sys_error(stat) then goto abort2;

  iho.flags := iho.flags + [ihn_flag_ownconn_k]; {indicate we created output conn}
  return;

abort2:                                {error with output file open}
  file_close (conn_p^);                {close connection to the output file}
  file_delete_name (conn_p^.tnam, stat2); {try to delete the file}

abort:                                 {error, STAT already set}
  sys_mem_dealloc (conn_p);            {deallocate file connection descriptor}
  end;
{
****************************************************************************
*
*   Subroutine ADD_BYTE (BUF, B, CKSUM)
*
*   Add the byte B to the end of the HEX file string BUF.  CKSUM is updated
*   to include B.
}
procedure add_byte (                   {add byte to output line}
  in out  buf: univ string_var_arg_t;  {text line to add byte to}
  in      b: int8u_t;                  {the byte value}
  in out  cksum: sys_int_machine_t);   {checksum updated to include byte}
  val_param;

var
  tk: string_var4_t;                   {scratch HEX number string}
  stat: sys_err_t;                     {completion status}

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int_max_base (              {make HEX number from byte value}
    tk,                                {output string}
    b,                                 {input integer}
    16,                                {radix}
    2,                                 {field width}
    [ string_fi_leadz_k,               {fill field with leading zeros as needed}
      string_fi_unsig_k],              {the input number is unsigned}
    stat);
  string_append (buf, tk);             {append hex number to end of string}
  cksum := (cksum + b) & 255;          {update checksum accumulator}
  end;
{
****************************************************************************
*
*   Subroutine IHEX_OUT_LINE (IHO, RTYPE, ADR, NDAT, DAT, STAT)
*
*   Low level routine to write one line to the HEX output stream.
*   RTYPE is the record type, ADR the address, NDAT the number of
*   data bytes, and DAT the array of data bytes.  The checksum will
*   be automatically computed and added to the output line.
}
procedure ihex_out_line (              {low level write one line to HEX stream}
  in out  iho: ihex_out_t;             {state for this use of HEX output routines}
  in      rtype: ihex_rtype_k_t;       {record type}
  in      adr: int32u_t;               {address for first data byte}
  in      ndat: sys_int_machine_t;     {number of data bytes, 0 - 255}
  in      dat: univ ihex_dat_t;        {the data bytes}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}
  cksum: sys_int_machine_t;            {checksum}
  buf: string_var1024_t;               {one line output buffer}

begin
  buf.max := size_char(buf.str);       {init local var string}

  cksum := 0;                          {init the checksum accumulator}
  buf.len := 0;                        {init output line to empty}
  string_append1 (buf, ':');           {write leading colon of HEX file line}
  add_byte (buf, ndat, cksum);         {number of data bytes later on line}
  add_byte (buf, rshft(adr, 8) & 255, cksum); {high address byte}
  add_byte (buf, adr & 255, cksum);    {low address byte}
  add_byte (buf, ord(rtype), cksum);   {record type}
  for i := 1 to ndat do begin          {once for each data byte}
    add_byte (buf, dat[i-1], cksum);
    end;
  cksum := (~cksum + 1) & 255;         {make final checksum value}
  add_byte (buf, cksum, i);            {append the checksum}

  file_write_text (buf, iho.conn_p^, stat); {write the line to the output stream}
  end;
{
****************************************************************************
*
*   Subroutine IHEX_OUT_FLUSH (IHO, STAT)
*
*   Force all buffered data, if any, to be written to the output stream.
}
procedure ihex_out_flush (             {write all buffered data, if any, to output}
  in out  iho: ihex_out_t;             {state for this use of HEX output routines}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  dat: array[0 .. 1] of int8u_t;       {data for LINEAR ADDRESS record}


begin
  sys_error_none (stat);               {init to no errors encountered}
  if iho.ndat <= 0 then return;        {no buffered data, nothing to do ?}

  if (iho.adrdat & 16#FFFF0000) <> iho.adrbase then begin {need set high adr bits ?}
    dat[0] := rshft(iho.adrdat, 24) & 255; {set the record data bytes}
    dat[1] := rshft(iho.adrdat, 16) & 255;
    ihex_out_line (                    {set high 16 bits of subsequent addresses}
      iho,                             {state for this use of IHEX_OUT_xxx routines}
      ihex_rtype_linadr_k,             {specify LINEAR ADDRESS record type}
      0,                               {address field value}
      2,                               {number of data bytes on this line}
      dat,                             {the array of data values}
      stat);
    if sys_error(stat) then return;
    iho.adrbase := iho.adrdat & 16#FFFF0000; {save new 64Kb region base address}
    end;

  ihex_out_line (                      {write the line with the data values}
    iho,                               {state for this use of IHEX_OUT_xxx routines}
    ihex_rtype_dat_k,                  {specify DATA record type}
    iho.adrdat & 16#FFFF,              {start address for data on this line}
    iho.ndat,                          {number of data bytes on this line}
    iho.dat,                           {the array of data values}
    stat);
  if sys_error(stat) then return;

  iho.ndat := 0;                       {reset to no data is buffered}
  end;
{
****************************************************************************
*
*   Subroutine IHEX_OUT_CLOSE (IHO, STAT)
*
*   Close the HEX output stream.  The underlying text output stream will
*   only be closed if it was created by the IHEX_OUT_xxx routines.
}
procedure ihex_out_close (             {close use of HEX output routines}
  in out  iho: ihex_out_t;             {state for this use of HEX output routines}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

label
  leave;

begin
  ihex_out_flush (iho, stat);          {write all buffered data, if any, to output}
  if sys_error(stat) then goto leave;

  ihex_out_line (                      {write end of file record}
    iho,                               {state for this use of IHEX_OUT_xxx routines}
    ihex_rtype_eof_k,                  {specify EOF record type}
    0,                                 {start address for data on this line}
    0,                                 {number of data bytes on this line}
    nil,                               {array of data values, unused}
    stat);

leave:                                 {common exit point, STAT already set}
  if ihn_flag_ownconn_k in iho.flags then begin {we created output connection ?}
    file_close (iho.conn_p^);          {close the output file}
    sys_mem_dealloc (iho.conn_p);      {deallocate output connection descriptor}
    end;
  end;
{
****************************************************************************
*
*   Subroutine IHEX_OUT_BYTE (IHO, ADR, B, STAT)
*
*   Write one data byte at a specific address to the HEX output stream.
*   The data may be buffered and written together with other data at
*   a later time.
}
procedure ihex_out_byte (              {write one data byte to HEX output file}
  in out  iho: ihex_out_t;             {state for this use of HEX output routines}
  in      adr: int32u_t;               {address of the data byte}
  in      b: int8u_t;                  {the data byte value}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

begin
  sys_error_none (stat);               {init to no error encountered}

  if                                   {this address must be on a new line ?}
      (iho.ndat > 0) and               {a previous line has already been started ?}
      ( ((adr & 16#FFFF0000) <> (iho.adrdat & 16#FFFF0000)) or {new 64Kb segment ?}
        (adr <> iho.adrdat + iho.ndat) ) {not immediately following previous byte ?}
      then begin
    ihex_out_flush (iho, stat);        {write old buffered data and empty buffer}
    end;

  if iho.ndat = 0 then begin           {this will be first byte on new line ?}
    iho.adrdat := adr;                 {set starting address for this line}
    end;

  iho.dat[iho.ndat] := b;              {save the data byte in the buffer}
  iho.ndat := iho.ndat + 1;            {count one more byte in the buffer}

  if iho.ndat >= iho.maxdat then begin {the line is full ?}
    ihex_out_flush (iho, stat);        {write the buffered data and clear the buffer}
    end;
  end;
