{   Public include file for STUFF library.  This library contains a collection
*   of unrelated utility routines.
}
const
  pi = 3.14159265358979323846;         {what it sounds like, don't touch}
  pi2 = pi * 2.0;                      {2 Pi}
{
*   Error status values related to the STUFF subsystem.
}
  stuff_subsys_k = -16;                {our subsystem ID}

  stuff_stat_queue_end_k = 1;          {end of queue encountered}
  stuff_stat_qent_open_k = 2;          {a queue entry is already open}
  stuff_stat_qent_nopen_k = 3;         {no queue entry currently open}
  stuff_stat_qopt_cmd_get_k = 4;       {error reading command from OPTIONS file}
  stuff_stat_qopt_cmd_bad_k = 5;       {unrecognized command in SMTP OPTIONS file}
  stuff_stat_qopt_parm_err_k = 6;      {err with command parm in OPTIONS file}
  stuff_stat_qopt_parm_extra_k = 7;    {too many parms in SMTP queue OPTIONS file}
  stuff_stat_qopt_parm_missing_k = 8;  {missing parm in SMTP queue OPTIONS file}
  stuff_stat_smtp_err_k = 9;           {general SMTP comm or handshaking error}
  stuff_stat_smtp_noqueue_k = 10;      {no such mail queue}
  stuff_stat_smtp_queue_full_k = 11;   {mail queue full or unrecognized error}
  stuff_stat_smtp_no_in_queue_k = 12;  {no mail input queue specified}
  stuff_stat_mailfeed_loop_k = 13;     {circular dependency in MAILFEED env set}
  stuff_stat_envcmd_bad_k = 14;        {bad command in environment file set}
  stuff_stat_envline_extra_k = 15;     {extra stuff after env file command}
  stuff_stat_envparm_missing_k = 16;   {missing parm to env file command}
  stuff_stat_envparm_err_k = 17;       {bad parameter to env file command}
  stuff_stat_smtp_resp_err_k = 18;     {error response from SMTP server}
  stuff_stat_ihex_eos_k = 19;          {unexpected early end of hex file line}
  stuff_stat_ihex_cksum_k = 20;        {checksum error on hex file line}
  stuff_stat_ihex_badchar_k = 21;      {illegal character in Intel HEX file}
  stuff_stat_ihex_badtype_k = 22;      {unrecognized Intel HEX file record type}
  stuff_stat_notwav_k = 23;            {file is not a valid WAV file}
  stuff_stat_wavenc_k = 24;            {unrecognized WAV encoding format}
  stuff_stat_wavencr_k = 25;           {requested WAV encoding is not supported}
  stuff_stat_mail_relay_k = 26;        {client tried to relay mail thru us}
  stuff_stat_ihex_eof_k = 28;          {end of HEX file before HEX EOF record}
  stuff_stat_csvfield_null_k = 29;     {CSV field is empty}
{
*   Other constants.
}
  wav_chan_max_k = 8;                  {max WAV file channels supported}
  wav_chan_last_k = wav_chan_max_k - 1; {last allowed channel number in a WAV file}

type
{
******************************
*
*   HTML file writing.
}
  htm_out_t = record                   {state for writing to an HTML file}
    conn: file_conn_t;                 {I/O connection to output file}
    buf: string_var8192_t;             {buffered output data not yet written}
    indent: sys_int_machine_t;         {number of characters to indent new lines}
    indent_lev: sys_int_machine_t;     {indentation level}
    indent_size: sys_int_machine_t;    {number of indentation chars per level}
    pad: boolean;                      {add separator before next free form token}
    wrap: boolean;                     {allow wrapping to next line at blanks}
    end;
  htm_out_p_t = ^htm_out_t;

  ihn_flag_k_t = (                     {flags in hex file reading state}
    ihn_flag_ownconn_k,                {we own CONN pointed to by CONN_P}
    ihn_flag_eof_k);                   {HEX file EOF record previously read}
  ihn_flag_t = set of ihn_flag_k_t;
{
******************************
*
*   Intel HEX file reading and writing.
}
  ihex_in_t = record                   {state for reading Intel HEX file stream}
    conn_p: file_conn_p_t;             {pnt to connection to the text input stream}
    adrbase: sys_int_conv32_t;         {base address for adr in individual records}
    ndat: sys_int_conv32_t;            {total number of data bytes read from HEX file}
    ibuf: string_var8192_t;            {one line input buffer}
    p: string_index_t;                 {IBUF parse index}
    cksum: int8u_t;                    {checksum of input line bytes processed so far}
    flags: ihn_flag_t;                 {set of individual flags}
    end;

  ihex_dat_t =                         {data bytes from one Intel HEX file line}
    array[0 .. 255] of int8u_t;        {max possible data bytes on one line}

  ihex_rtype_k_t = int8u_t (           {different Intel HEX file record types}
    ihex_rtype_dat_k = 0,              {data record}
    ihex_rtype_eof_k = 1,              {end of file}
    ihex_rtype_segadr_k = 2,           {segmented address}
    ihex_rtype_linadr_k = 4);          {linear address record}

  ihex_out_t = record                  {state for writing to Intel HEX file stream}
    conn_p: file_conn_p_t;             {pnt to connection to the text output stream}
    adrbase: int32u_t;                 {start address of current 64Kb region}
    maxdat: sys_int_machine_t;         {max data values allowed on one HEX out line}
    adrdat: int32u_t;                  {address for first data byte in DAT}
    ndat: sys_int_machine_t;           {number of data values in DAT}
    dat: ihex_dat_t;                   {buffered data values not yet written}
    flags: ihn_flag_t;                 {set of individual flags}
    end;
{
******************************
*
*   WAV file reading and writing.
}
  wav_enc_k_t = (                      {WAV encoding formats}
    wav_enc_samp_k);                   {uncompressed samples at regular intervals}

  wav_iterp_k_t = (                    {WAV data interpolation modes}
    wav_iterp_pick_k,                  {pick nearest sample}
    wav_iterp_lin_k,                   {linearly interpolate two nearest}
    wav_iterp_cubic_k);                {cubically interpolate four nearest}

  wav_info_t = record                  {info about WAV data}
    enc: wav_enc_k_t;                  {encoding format}
    nchan: sys_int_machine_t;          {number of audio channels}
    srate: real;                       {sample rate in Hz}
    cbits: sys_int_machine_t;          {bits per channel within a sample}
    cbytes: sys_int_adr_t;             {bytes per channel within a sample}
    sbytes: sys_int_adr_t;             {bytes per sample for all channels}
    end;

  wav_in_t = record                    {state for reading one WAV file}
    {
    *   These fields may be read by applications.
    }
    info: wav_info_t;                  {general info about the WAV data}
    dt: real;                          {seconds between samples}
    tsec: real;                        {total seconds playback time}
    nsamp: sys_int_conv32_t;           {total number of samples}
    salast: sys_int_conv32_t;          {0-N number of the last sample (NSAMP-1)}
    chlast: sys_int_machine_t;         {0-N number of the last channel}
    conn: file_conn_t;                 {connection to WAV file}
    mem_p: util_mem_context_p_t;       {mem context for this WAV file connection}
    {
    *   These fields are private to the WAV file input routines and should
    *   not be accessed by applications.
    }
    map: file_map_handle_t;            {handle to entire WAV file mapped into memory}
    wav_p: univ_ptr;                   {points to WAV file mapped into memory}
    wavlen: sys_int_adr_t;             {total length of the WAV file mapped to mem}
    dat_p: univ_ptr;                   {points to raw WAV data mapped into memory}
    datlen: sys_int_adr_t;             {length of the raw data starting at DAT_P^}
    end;
  wav_in_p_t = ^wav_in_t;

  wav_samp_t =                         {raw sample data of a WAV file}
    array[0 .. wav_chan_last_k] of real;

  wav_kern_t = array[0 .. 0] of real;  {filter kernel template}
  wav_kern_p_t = ^wav_kern_t;

  wav_filt_t = record                  {info for filtering WAV input data}
    wavin_p: wav_in_p_t;               {pointer to WAV input reading state}
    np: sys_int_machine_t;             {number of points in convolution kernel}
    plast: sys_int_machine_t;          {0-N number of last filter point}
    dp: real;                          {delta seconds between convolution points}
    t0: real;                          {relative seconds offset for first kernel pnt}
    kern_p: wav_kern_p_t;              {pointer to convolution kernel function}
    ugain: boolean;                    {normalize filter output for unity gain}
    end;

  wav_out_t = record                   {state for writing to a WAV file}
    info: wav_info_t;                  {info about the WAV data}
    nsamp: sys_int_conv32_t;           {number of samples written so far}
    salast: sys_int_conv32_t;          {0-N number of the last sample (NSAMP-1)}
    chlast: sys_int_machine_t;         {0-N number of the last channel}
    conn: file_conn_t;                 {connection to binary output file}
    buf: array[0 .. 8192] of char;     {output buffer}
    bufn: sys_int_adr_t;               {number of bytes in BUF}
    end;
  wav_out_p_t = ^wav_out_t;
{
******************************
*
*   Quoted printable encoded data handling.
}
  qprflag_k_t = (                      {flags for reading quoted printable text}
    qprflag_conn_close_k,              {close input CONN on EOF}
    qprflag_conn_del_k,                {delete input CONN after close}
    qprflag_passthru_k);               {pass input stream thru without interpreting}
  qprflags_t = set of qprflag_k_t;     {all the flags in one word}

  qprint_read_t = record               {state for reading quoted printable stream}
    buf: string_var1024_t;             {one line input buffer}
    p: string_index_t;                 {BUF parse index}
    flags: qprflags_t;                 {set of individual flags}
    conn_p: file_conn_p_t;             {points to quoted printable text input stream}
    end;
  qprint_read_p_t = ^qprint_read_t;
{
******************************
*
*   CSV file writing.
}
  csv_in_p_t = ^csv_in_t;
  csv_in_t = record                    {data per CSV input file connection}
    conn: file_conn_t;                 {connection to the file, open for text read}
    buf: string_var8192_t;             {one line input buffer}
    p: string_index_t;                 {input line parse index}
    field: sys_int_machine_t;          {1-N field number last read, 0 before line}
    open: boolean;                     {connection to the CSV file is open}
    end;

  csv_out_p_t = ^csv_out_t;
  csv_out_t = record                   {data per CSV output file connection}
    conn: file_conn_t;                 {connection to the CSV file, open for text write}
    buf: string_var8192_t;             {buffer for next line to write}
    open: boolean;                     {connection to CSV file is open}
    end;
{
******************************
*
*   List of name/value pairs.
}
  nameval_ent_p_t = ^nameval_ent_t;
  nameval_ent_t = record
    prev_p: nameval_ent_p_t;           {points to previous list entry}
    next_p: nameval_ent_p_t;           {points to next list entry}
    name_p: string_var_p_t;            {the name string}
    value_p: string_var_p_t;           {the value associated with the name}
    end;

  nameval_list_p_t = ^nameval_list_t;
  nameval_list_t = record
    mem_p: util_mem_context_p_t;       {points to dynamic memory context for list}
    first_p: nameval_ent_p_t;          {points to first list entry}
    last_p: nameval_ent_p_t;           {points to last list entry}
    nents: sys_int_machine_t;          {number of entries in the list}
    memcr: boolean;                    {private memory context created}
    end;
{
******************************
*
*   Entry points.
}
procedure csv_in_close (               {close CSV input file}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

function csv_in_field_fp (             {get next CSV line field as floating point}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t)             {completion status}
  :sys_fp_max_t;                       {returned field value, 0.0 on error}
  val_param; extern;

function csv_in_field_int (            {get next CSV line field as integer}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t)             {completion status}
  :sys_int_max_t;                      {returned field value, 0 on error}
  val_param; extern;

procedure csv_in_field_str (           {read next field from current CSV input line}
  in out  cin: csv_in_t;               {CSV file reading state}
  in out  str: univ string_var_arg_t;  {returned field contents}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_in_line (                {read next line from CSV file}
  in out  cin: csv_in_t;               {CSV file reading state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_in_open (                {open CSV input file}
  in      fnam: univ string_var_arg_t; {CSV file name, ".csv" suffix may be omitted}
  out     cin: csv_in_t;               {returned CSV reading state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

function csvfield_null (               {check for empty CSV file field}
  in out  stat: sys_err_t)             {STAT to test, reset on returning TRUE}
  :boolean;                            {STAT is indicating empty CSV file field}
  val_param; extern;

procedure csv_out_close (              {close CSV output file}
  in out  csv: csv_out_t;              {CSV file writing state, returned invalid}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_fp_fixed (           {write fixed format floating point as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      fp: double;                  {floating point value to write}
  in      digr: sys_int_machine_t;     {digits right of decimal point}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_fp_free (            {write free format floating point as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      fp: double;                  {floating point value to write}
  in      sig: sys_int_machine_t;      {number of significant digits}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_fp_ftn (             {write FP as next CSV field, FTN formatting}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      fp: double;                  {floating point value to write}
  in      fw: sys_int_machine_t;       {minimum total number width}
  in      digr: sys_int_machine_t;     {digits right of decimal point}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_blank (              {write completely blank field, not quoted}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      n: sys_int_machine_t;        {number of blanks to write}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_int (                {write integer as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      i: sys_int_max_t;            {integer value}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_line (               {write curr line to CSV file, will be reset to empty}
  in out  csv: csv_out_t;              {CSV file writing state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_open (               {open CSV output file}
  in      fnam: univ string_var_arg_t; {CSV file name, ".csv" suffix may be omitted}
  out     csv: csv_out_t;              {returned CSV file writing state}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_str (                {string as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      str: string;                 {string to write as field, trailing blanks ignored}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure csv_out_vstr (               {var string as next CSV field}
  in out  csv: csv_out_t;              {CSV file writing state}
  in      vstr: univ string_var_arg_t; {string to write as single field}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure htm_close_write (            {close HTML file open for writing}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_open_write_name (        {open/create HTML output file by name}
  out     hout: htm_out_t;             {returned initialized HTM writing state}
  in      fnam: univ string_var_arg_t; {pathname of file to open or create}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_bline (            {write blank line to HTML output file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_buf (              {write all buffered data, if any, to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_color (            {write a color value in HTML format, no blank before}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      red, grn, blu: real;         {color components in 0-1 scale}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_color_gray (       {write gray color value in HTML format, no blank before}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      gray: real;                  {0-1 gray value}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_indent (           {indent HTM writing by one level}
  in out  hout: htm_out_t);            {state for writing to HTML output file}
  val_param; extern;

procedure htm_write_indent_abs (       {set HTM absolute output indentation level}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      indabs: sys_int_machine_t);  {new absolute indentation level}
  val_param; extern;

procedure htm_write_indent_rel (       {set HTM relative output indentation level}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      indrel: sys_int_machine_t);  {additional levels to indent, may be neg}
  val_param; extern;

procedure htm_write_undent (           {un-indent HTM writing by one level}
  in out  hout: htm_out_t);            {state for writing to HTML output file}
  val_param; extern;

procedure htm_write_line (             {write complete text line to HTM output file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      line: univ string_var_arg_t; {line to write, will be HTM line exactly}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_line_str (         {write complete text line to HTM output file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      line: string;                {line to write, NULL term or blank padded}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_newline (          {new data goes to new line of HTML file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_nopad (            {inhibit blank before next free format token}
  in out  hout: htm_out_t);            {state for writing to HTML output file}
  val_param; extern;

procedure htm_write_pre_line (         {write one line of pre-formatted text}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      line: univ string_var_arg_t; {line to write, HTM control chars converted}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_pre_end (          {stop writing pre-formatted text}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_pre_start (        {start writing pre-formatted text}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_str (              {write free format string to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      str: string;                 {string to write, NULL term or blank padded}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_vstr (             {write free format string to HTM file}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      str: univ string_var_arg_t;  {string to write}
  out     stat: sys_err_t);            {completion status code}
  val_param; extern;

procedure htm_write_wrap (             {set wrapping to new lines a blanks}
  in out  hout: htm_out_t;             {state for writing to HTML output file}
  in      onoff: boolean);             {TRUE enables wrapping, FALSE disables}
  val_param; extern;

procedure ihex_in_close (              {close a use of the IHEX_IN routines}
  in out  ihn: ihex_in_t;              {state this use of routines, returned invalid}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_in_dat (                {get data bytes from next HEX file data rec}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     adr: int32u_t;               {address of first data byte in DAT}
  out     nd: sys_int_machine_t;       {0-255 number of data bytes in DAT}
  out     dat: ihex_dat_t;             {the data bytes}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_in_line_raw (           {read hex file line and return the raw info}
  in out  ihn: ihex_in_t;              {state for reading HEX file stream}
  out     nd: sys_int_machine_t;       {0-255 number of data bytes}
  out     adr: int32u_t;               {address represented by address field}
  out     rtype: ihex_rtype_k_t;       {record type ID}
  out     dat: ihex_dat_t;             {the data bytes}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_in_open_conn (          {open HEX in routines with existing stream}
  in out  conn: file_conn_t;           {connection to the input stream}
  out     ihn: ihex_in_t;              {returned state for this IHEX input stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_in_open_fnam (          {open HEX in routines with file name}
  in      fnam: univ string_var_arg_t; {file name}
  in      ext: string;                 {file name suffix}
  out     ihn: ihex_in_t;              {returned state for this IHEX input stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_out_byte (              {write one data byte to HEX output file}
  in out  iho: ihex_out_t;             {state for this use of HEX output routines}
  in      adr: int32u_t;               {address of the data byte}
  in      b: int8u_t;                  {the data byte value}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_out_close (             {close use of HEX output routines}
  in out  iho: ihex_out_t;             {state for this use of HEX output routines}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_out_open_conn (         {open HEX out routines with existing stream}
  in out  conn: file_conn_t;           {connection to the existing output stream}
  out     iho: ihex_out_t;             {returned state for writing to HEX stream}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure ihex_out_open_fnam (         {open HEX out routines to write to file}
  in      fnam: univ string_var_arg_t; {file name}
  in      ext: string;                 {file name suffix}
  out     iho: ihex_out_t;             {returned state for writing to HEX file}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure nameval_ent_add_end (        {add name/value entry to end of list}
  in out  list: nameval_list_t;        {the list to add the entry to}
  in      ent_p: nameval_ent_p_t);     {pointer to the entry to add}
  val_param; extern;

procedure nameval_ent_new (            {create and initialize new name/value list entry}
  in out  list: nameval_list_t;        {the list to create entry for}
  out     ent_p: nameval_ent_p_t);     {returned pointer to the new entry}
  val_param; extern;

function nameval_get_val (             {look up name and get associated value}
  in      list: nameval_list_t;        {the list to look up in}
  in      name: univ string_var_arg_t; {the name to look up}
  in out  val: univ string_var_arg_t)  {returned value, empty string on not found}
  :boolean;                            {name was found}
  val_param; extern;

procedure nameval_list_del (           {delete (deallocate resources) of list}
  in out  list: nameval_list_t);       {the list to deallocate resources of}
  val_param; extern;

procedure nameval_list_init (          {initialize list of name/value pairs}
  out     list: nameval_list_t;        {the list to initialize}
  in out  mem: util_mem_context_t);    {parent memory context, will create subordinate}
  val_param; extern;

function nameval_match (               {find whether name/value matches a list entry}
  in      list: nameval_list_t;        {the list to match against}
  in      name: univ string_var_arg_t; {the name to match}
  in      val: univ string_var_arg_t)  {the value to match}
  :sys_int_machine_t;                  {-1 = mismatch, 0 = no relevant entry, 1 = match}
  val_param; extern;

procedure nameval_set_name (           {set name in name/value list entry}
  in      list: nameval_list_t;        {the list the entry is associated with}
  out     ent: nameval_ent_t;          {the entry to set the name of}
  in      name: univ string_var_arg_t); {the name to write into the entry}
  val_param; extern;

procedure nameval_set_value (          {set value in name/value list entry}
  in      list: nameval_list_t;        {the list the entry is associated with}
  out     ent: nameval_ent_t;          {the entry to set the value of}
  in      value: univ string_var_arg_t); {the value to write into the entry}
  val_param; extern;

procedure qprint_read_char (           {decode next char from quoted printable strm}
  in out  qprint: qprint_read_t;       {state for reading quoted printable stream}
  out     c: char;                     {next character decoded from the stream}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure qprint_read_char_str (       {decode quoted printable char from string}
  in      buf: univ string_var_arg_t;  {qprint input string, no trailing blanks}
  in out  p: string_index_t;           {parse index, init to 1 for start of string}
  in      single: boolean;             {single string, not in succession of lines}
  out     c: char;                     {returned decoded character}
  out     stat: sys_err_t);            {completion status, EOS on input string end}
  val_param; extern;

procedure qprint_read_close (          {deallocate resources for reading quoted print}
  in out  qprint: qprint_read_t;       {reading state, returned invalid}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure qprint_read_getline (        {abort this input line, get next}
  in out  qprint: qprint_read_t;       {reading state, returned invalid}
  out     stat: sys_err_t);            {completion status, can be EOF}
  val_param; extern;

procedure qprint_read_open_conn (      {set up for reading quoted printable stream}
  out     qprint: qprint_read_t;       {reading state, will be initialized}
  in out  conn: file_conn_t;           {connection to quoted printable input stream}
  out     stat: sys_err_t);            {completion status}
  val_param; extern;

procedure wav_filt_aa (                {set up anti-aliasing filter}
  in out  wavin: wav_in_t;             {state for reading WAV input stream}
  in      fcut: real;                  {cutoff frequency, herz}
  in      attcut: real;                {min required attenuation at cutoff freq}
  out     filt: wav_filt_t);           {returned initialized filter info}
  val_param; extern;

procedure wav_filt_init (              {init WAV input filter}
  in out  wavin: wav_in_t;             {state for reading WAV input stream}
  in      tmin: real;                  {seconds offset for first filter kernel point}
  in      tmax: real;                  {seconds offset for last filter kernel point}
  in      ffreq: real;                 {Hz samp freq for defining filter function}
  out     filt: wav_filt_t);           {initialized filter info, filter all zero}
  val_param; extern;

function wav_filt_samp_chan (          {get filtered value of channel in sample}
  in out  filt: wav_filt_t;            {info for filtering WAV input stream}
  in      t: real;                     {WAV input time at which to create sample}
  in      chan: sys_int_machine_t)     {0-N channel number, -1 to average all}
  :real;                               {-1 to +1 sample value}
  val_param; extern;

function wav_filt_val (                {get interpolated filter kernel value}
  in out  filt: wav_filt_t;            {info for filtering WAV input stream}
  in      t: real)                     {filter time, pos for past, neg for future}
  :real;                               {filter kernel interpolated to filter time T}
  val_param; extern;

procedure wav_in_close (               {close WAV input file}
  in out  wavin: wav_in_t;             {state for reading WAV file, returned invalid}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure wav_in_open_fnam (           {open WAV input file by name}
  out     wavin: wav_in_t;             {returned state for this use of WAV_IN calls}
  in      fnam: univ string_treename_t; {input file name}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

function wav_in_iterp_chan (           {get interpolated WAV input signal}
  in out  wavin: wav_in_t;             {state for reading WAV input signal}
  in      t: real;                     {WAV input time at which to interpolate}
  in      iterp: wav_iterp_k_t;        {interpolation mode to use}
  in      chan: sys_int_machine_t)     {0-N channel number, -1 to average all}
  :real;                               {interpolated WAV value at T}
  val_param; extern;

procedure wav_in_samp (                {get all the data of one sample}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in      n: sys_int_conv32_t;         {0-N sample number}
  out     chans: univ wav_samp_t);     {-1 to 1 data for each channel}
  val_param; extern;

function wav_in_samp_chan (            {get particular channel value within sample}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in      n: sys_int_conv32_t;         {0-N sample number}
  in      chan: sys_int_machine_t)     {0-N channel number, -1 to average all}
  :real;                               {-1 to +1 sample value}
  val_param; extern;

function wav_in_samp_mono (            {get mono value of particular sample in WAV}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in      n: sys_int_conv32_t)         {0-N sample number}
  :real;                               {-1 to +1 sample value}
  val_param; extern;

procedure wav_out_close (              {close WAV output file}
  in out  wavot: wav_out_t;            {state for writing WAV file, returned invalid}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure wav_out_open_fnam (          {open WAV output file by name}
  out     wavot: wav_out_t;            {returned state for this use of WAV_OUT calls}
  in      fnam: univ string_treename_t; {output file name}
  in      info: wav_info_t;            {info about the WAV data}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure wav_out_samp (               {write next sample to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      chans: univ wav_samp_t;      {-1 to 1 data for each chan within the sample}
  in      nchan: sys_int_machine_t;    {number of chans data supplied for in CHANS}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;

procedure wav_out_samp_mono (          {write monophonic sample to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: real;                   {-1.0 to 1.0 value for all channels}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; extern;
