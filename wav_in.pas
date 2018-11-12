{   Module of routines for reading WAV files.  These routines are exported
*   in the STUFF library.
}
module wav_in;
define wav_in_open_fnam;
define wav_in_close;
define wav_in_samp_chan;
define wav_in_samp;
define wav_in_samp_mono;
define wav_in_iterp_chan;
%include 'stuff2.ins.pas';
{
*   Private routines used inside this module only.
}
function wav_in_byte (                 {get raw 0-255 byte value from WAV file}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to byte, will be incremented}
  :int8u_t;                            {returned 0-255 byte value}
  val_param; internal; forward;

function wav_in_i16u (                 {get unsigned 16 bit integer WAV file value}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to value, will be incremented}
  :int8u_t;                            {returned 0-65535 value}
  val_param; internal; forward;

function wav_in_i16s (                 {get signed 16 bit integer WAV file value}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to value, will be incremented}
  :int16u_t;                           {returned -32768 to 32767 value}
  val_param; internal; forward;

function wav_in_i32u (                 {get unsigned 32 bit integer WAV file value}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to value, will be incremented}
  :int32u_t;                           {returned 0 to 2**32-1 value}
  val_param; internal; forward;

procedure wav_in_str (                 {get fixed length string from WAV file}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr;                 {pointer to value, will be incremented}
  in      n: sys_int_machine_t;        {number of characters in the string}
  in out  str: univ string_var_arg_t); {the returned string}
  val_param; internal; forward;
{
****************************************************************************
*
*   Subroutine WAV_IN_OPEN_FNAM (WAVIN, FNAM, STAT)
*
*   Open a WAV file for reading by the routines in this module.  WAVIN is the
*   WAV file reading state, which is initialized by this routine.  FNAM is
*   the WAV file name, although the ".wav" file name suffix may be omitted.
}
procedure wav_in_open_fnam (           {open WAV input file by name}
  out     wavin: wav_in_t;             {returned state for this use of WAV_IN calls}
  in      fnam: univ string_treename_t; {input file name}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  finfo: file_info_t;                  {file system info about the WAV file}
  fmt: wav_fmt_t;                      {data from WAV "fmt" chunk}
  olen: sys_int_adr_t;                 {amount of data actually transferred}
  p: univ_ptr;                         {current WAV file reading pointer}
  chname: string_var4_t;               {name of current chunk}
  adr: sys_int_adr_t;                  {scratch address}
  pick: sys_int_machine_t;             {number of token picked from list}
  in_riff: boolean;                    {within outer RIFF chunk}
  in_wave: boolean;                    {within WAVE chunk}

label
  loop_chunk, done_chunks,
  wav_fmt_bad, abort1;

begin
  chname.max := size_char(chname.str); {init local var string}

  file_open_map (                      {open WAV file for memory mapped access}
    fnam, '.wav',                      {input file name and mandatory suffix}
    [file_rw_read_k],                  {open of read access only}
    wavin.conn,                        {returned connection to the file}
    stat);
  if sys_error(stat) then return;

  file_info (                          {get the length of this file}
    wavin.conn.tnam,                   {name of file to get info about}
    [file_iflag_len_k],                {type of info being requested}
    finfo,                             {the returned file info}
    stat);
  if sys_error(stat) then goto abort1;
  wavin.wavlen := finfo.len;           {save length of the whole WAV file}

  file_map (                           {map the entire WAV file into memory}
    wavin.conn,                        {connection to the file}
    0,                                 {file offset for start of region to map}
    finfo.len,                         {length of region to map (entire file)}
    [file_rw_read_k],                  {requesting read-only access}
    wavin.wav_p,                       {returned pointer to start of mapped region}
    olen,                              {length actually mapped}
    wavin.map,                         {handle to the mapped region}
    stat);
  if sys_error(stat) then goto abort1;
{
*   The WAV file has been opened and mapped to memory starting at WAVIN.ADR.
*
*   Now wade thru the headers and process the WAV subchunks until the "data"
*   subchunk is encountered.
}
  in_riff := false;                    {init to not within RIFF chunk}
  in_wave := false;                    {init to not within WAVE chunk}
  fmt.size := 0;                       {init to no "fmt" chunk found yet}
  p := wavin.wav_p;                    {init WAV read pointer to start of file}

loop_chunk:                            {back here to read each new chunk}
  wav_in_str (wavin, p, 4, chname);    {get the chunk name}

  if                                   {WAV file must start with "RIFF"}
      (not in_riff) and                {at start of file ?}
      (not string_equal (chname, string_v('RIFF'))) {top chunk is not RIFF ?}
    then goto wav_fmt_bad;

  string_unpad (chname);               {remove any trailing spaces}
  string_tkpick80 (chname,             {pick chunk name from list}
    'RIFF LIST WAVE fmt data',
    pick);
  case pick of
{
*   RIFF chunk.  This must be the outer chunk, and is only allowed as the
*   first chunk.
}
1: begin
  if in_riff then goto wav_fmt_bad;
  in_riff := true;

  discard( wav_in_i32u (wavin, p) );   {skip over length word}
  end;
{
*   LIST chunk.  The wave chunk we want could be within one of these.
}
2: begin
  discard( wav_in_i32u (wavin, p) );   {skip over length word}
  end;
{
*   WAVE chunk.  This has no data of its own, not even a length word.
}
3: begin
  if in_wave then goto wav_fmt_bad;
  in_wave := true;
  end;
{
*   "fmt" chunk.  This describes the format of WAVE data.
}
4: begin
  if not in_wave then goto wav_fmt_bad;

  fmt.size := wav_in_i32u (wavin, p);  {get remaining length of this chunk}
  if odd(fmt.size) then fmt.size := fmt.size + 1; {round up to even len}
  adr := sys_int_adr_t(p) + fmt.size;  {make first address after this chunk}

  fmt.dtype := wav_in_i16s (wavin, p);
  fmt.n_chan := wav_in_i16u (wavin, p);
  fmt.samp_sec := wav_in_i32u (wavin, p);
  fmt.bytes_sec := wav_in_i32u (wavin, p);
  fmt.bytes_samp := wav_in_i16u (wavin, p);
  fmt.bits_samp := wav_in_i16u (wavin, p);

  fmt.more_p := p;                     {save pointer to additional FMT data, if any}
  p := univ_ptr(adr);                  {continue with next byte after this chunk}
  end;
{
*   "data" chunk.  Starts with length word, then contains the raw WAV data.
}
5: begin
  if not in_wave then goto wav_fmt_bad;
  if fmt.size = 0 then goto wav_fmt_bad;

  fmt.dsize := wav_in_i32u (wavin, p); {get remaining length of this chunk}
  fmt.data_p := p;                     {save pointer to start of raw data}
  fmt.data_end_p := univ_ptr(          {set pointer to first adr after data end}
    sys_int_adr_t(p) + fmt.dsize);
  fmt.nsamp := fmt.dsize div fmt.bytes_samp; {number of whole samples in the data}
  fmt.bytes_sampp := (fmt.bits_samp + 7) div 8;

  goto done_chunks;                    {done looking thru chunks}
  end;
{
*   Unrecognized chunk types.  These will be assumed to have a length word
*   following the chunk name, and will be skipped over entirely.
}
otherwise                              {unrecognized chunk type}
    adr := wav_in_i32u (wavin, p);     {get size of this chunk}
    if odd(adr) then adr := adr + 1;   {round up to even chunk size}
    p := univ_ptr(                     {jump to first address after this chunk}
      sys_int_adr_t(p) + adr);
    end;
  goto loop_chunk;                     {back to process next chunk}

done_chunks:                           {done processing chunks, data chunk found}
{
*   All the control info about the WAV data has been read into FMT.
}
  case fmt.dtype of                    {what is encoding format ?}
1:  begin                              {uncompressed samples at regular intervals}
      wavin.info.enc := wav_enc_samp_k;
      end;
otherwise
    sys_stat_set (stuff_subsys_k, stuff_stat_wavenc_k, stat);
    sys_stat_parm_int (ord(fmt.dtype), stat);
    sys_stat_parm_vstr (wavin.conn.tnam, stat);
    goto abort1;
    end;
  wavin.info.nchan := fmt.n_chan;      {number of audio channels}
  wavin.info.srate := fmt.samp_sec;    {sample rate in Hz}
  wavin.info.cbits := fmt.bits_samp;   {bits per channel value}
  wavin.info.cbytes := fmt.bytes_sampp; {bytes storage used for each channel value}
  wavin.info.sbytes := fmt.bytes_samp; {bytes per sample for all channels}
  wavin.dt := 1.0 / wavin.info.srate;  {seconds between data points}
  wavin.tsec := fmt.nsamp / fmt.samp_sec; {total seconds playback time}
  wavin.nsamp := fmt.nsamp;            {number of samples}
  wavin.salast := wavin.nsamp - 1;     {number of the last sample}
  wavin.chlast := wavin.info.nchan - 1; {number of the last channel}
  wavin.dat_p := fmt.data_p;           {start address of the raw data in memory}
  wavin.datlen := fmt.dsize;           {size of the raw data in memory}
  util_mem_context_get (util_top_mem_context, wavin.mem_p); {create memory context}
  return;                              {normal return point}
{
*   Error exits.
}
wav_fmt_bad:                           {input file is not a valid WAV file}
  sys_stat_set (stuff_subsys_k, stuff_stat_notwav_k, stat);
  sys_stat_parm_vstr (wavin.conn.tnam, stat);
  goto abort1;

abort1:                                {WAV file open, STAT already set}
  file_close (wavin.conn);             {close the connection to the WAV file}
  end;
{
****************************************************************************
*
*   Subroutine WAV_IN_CLOSE (WAVIN, STAT)
*
*   Close the connection to the WAV input file and release any related
*   resources.  WAVIN is retuned invalid.
}
procedure wav_in_close (               {close WAV input file}
  in out  wavin: wav_in_t;             {state for reading WAV file, returned invalid}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

begin
  sys_error_none(stat);                {init to no error encountered}

  util_mem_context_del (wavin.mem_p);  {dealloc mem associated with this WAV input}
  file_close (wavin.conn);             {close the connection to the file}
  end;
{
****************************************************************************
*
*   Function WAV_IN_SAMP_CHAN (WAVIN, N, CHAN)
*
*   Returns the -1 to +1 value of channel CHAN within the sample N.  Both
*   channel and sample numbers start at 0.  Zero is returned if N and/or
*   CHAN are out of range.  The special value of -1 for the channel number
*   causes the average of all the samples to be returned.
}
function wav_in_samp_chan (            {get particular channel value within sample}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in      n: sys_int_conv32_t;         {0-N sample number}
  in      chan: sys_int_machine_t)     {0-N channel number, -1 to average all}
  :real;                               {-1 to +1 sample value}
  val_param;

var
  p: univ_ptr;                         {pointer to this specific data}
  j: sys_int_machine_t;                {loop counters and scratch integers}
  chu: sys_int_machine_t;              {channel number to actually use to adr mem}
  ch: sys_int_conv32_t;                {channel value normalized to 16 bits}
  acc: real;                           {accumulator for averaging channel values}

begin
  wav_in_samp_chan := 0.0;             {init for out of range input parameters}
  if (n < 0) or (n >= wavin.nsamp) then return; {before or after input signal ?}
  if (chan < -1) or (chan >= wavin.info.nchan) then return; {no such channel ?}

  chu := chan;                         {init channel number to make mem adr from}
  if chan = -1 then begin              {need to average all channels ?}
    if wavin.chlast > 0
      then begin                       {there are multiple channels to average}
        acc := 0.0;                    {init sum of channels}
        for j := 0 to wavin.chlast do begin {once for each channel to average}
          acc := acc + wav_in_samp_chan (wavin, n, j); {add value of this channel}
          end;
        wav_in_samp_chan := acc / wavin.info.nchan; {return ave of all the channels}
        return;
        end
      else begin                       {only one channel, nothing to average}
        chu := 0;                      {set number of channel to return data from}
        end
      ;
    end;
{
*   The sample and channel numbers are valid.
}
  p := univ_ptr(                       {make pointer to start of this specific data}
    sys_int_adr_t(wavin.dat_p) +       {start of the raw data}
    n * wavin.info.sbytes +            {offset to start of this sample}
    chu * wavin.info.cbytes);          {offset from start of sample to this channel}

  if wavin.info.cbytes = 1
    then begin                         {channel value is single unsigned byte}
      ch := lshft(wav_in_byte(wavin, p), 8);
      end
    else begin                         {multiple bytes forming signed integer}
      ch := 0;                         {stop compiler from complaining CH is uninit}
      for j := 1 to wavin.info.cbytes do begin {once for each byte in sample}
        ch := rshft(ch, 8);            {make room for the new byte}
        ch := ch ! lshft(wav_in_byte(wavin, p), 8); {merge in byte}
        end;                           {back for next byte in this sample point}
      ch := ch + 32768;                {convert to unsigned integer sample value}
      ch := ch & 16#FFFF;
      end
    ;
{
*   The unsigned integer value of this channel value is left justified in the
*   low 16 bits of CH.
*
*   Now replicate the high sample bits into the low bits until all low 16 bits
*   of CH are filled with valid data.  This results in a sample value with the
*   range of 0 to 65535 regardless of the original format.
}
  j := wavin.info.cbits;               {init number of valid bits currently in CH}
  while j < 16 do begin                {loop until high bits replicated into all low}
    ch := ch ! rshft(ch, j);           {replicate high J bits into next J bits}
    j := j + j;                        {update number of valid bits now in CH}
    end;                               {back until all 16 CH bits filled}

  ch := ch - 32768;                    {convert to signed 16 bit integer value}
  wav_in_samp_chan := ch / 32768.0;    {pass back final -1.0 to +1.0 channel value}
  end;
{
****************************************************************************
*
*   Subroutine WAV_IN_SAMP (WAVIN, N, CHANS)
*
*   Get all the data of sample N.  Sample numbers start with N.  The CHANS
*   entries for the existing channels are set to the -1 to +1 value for that
*   channel.  Additional CHANS entries, if any, are untouched and need
*   not exist.  Zero is returned for all channels if sample N does not
*   exist.
}
procedure wav_in_samp (                {get all the data of one sample}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in      n: sys_int_conv32_t;         {0-N sample number}
  out     chans: univ wav_samp_t);     {-1 to 1 data for each channel}
  val_param;

var
  i: sys_int_machine_t;                {loop counter}

begin
  for i := 0 to wavin.chlast do begin  {once for each channel in the sample}
    chans[i] := wav_in_samp_chan (wavin, n, i); {get the value for this channel}
    end;
  end;
{
****************************************************************************
*
*   Function WAV_IN_SAMP_MONO (WAVIN, N)
*
*   Return the monophonic value of the WAV file sample N.  Valid samples
*   are numbered 0 thru WAVIN.NSAMP-1.  Zero is returned for values outside
*   this range.
}
function wav_in_samp_mono (            {get mono value of particular sample in WAV}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in      n: sys_int_conv32_t)         {0-N sample number}
  :real;                               {-1 to +1 sample value}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}
  acc: real;                           {accumulator for all the channel values}

begin
  acc := 0.0;                          {init the sum of channel values}
  for i := 0 to wavin.info.nchan-1 do begin {once for each channel}
    acc := acc + wav_in_samp_chan (wavin, n, i); {add in value of this channel}
    end;
  wav_in_samp_mono := acc / wavin.info.nchan; {return average of all the channels}
  end;
{
****************************************************************************
*
*   Function WAV_IN_BYTE (WAVIN, P)
*
*   Returns the byte at memory address P from the WAV file.  This routine
*   must not be called with P pointing to an address outside the memory mapped
*   window of the WAV file.
*
*   P will be incremented to point to the next WAV file byte.
}
function wav_in_byte (                 {get raw 0-255 byte value from WAV file}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to byte, will be incremented}
  :int8u_t;                            {returned 0-255 byte value}
  val_param; internal;

var
  bp: ^int8u_t;                        {pointer to the source byte}

begin
  if                                   {outside the memory mapped WAV file window ?}
      (sys_int_adr_t(p) < sys_int_adr_t(wavin.wav_p)) or {before ?}
      (sys_int_adr_t(p) > (sys_int_adr_t(wavin.wav_p) + wavin.wavlen)) {after ?}
      then begin
    writeln ('*** INTERNAL ERROR ***');
    writeln ('WAV_IN_BYTE in the WAV_IN module called with pointer out of range.');
    sys_bomb;
    end;

  bp := p;                             {set pointer to the source byte}
  wav_in_byte := bp^;                  {fetch and return the byte}
  p := succ(bp);                       {advance the pointer to the next byte}
  end;
{
****************************************************************************
*
*   Function WAV_IN_I16U (WAVIN, P)
*
*   Returns the 16 bit unsigned integer value in the WAV file at P.  P will
*   be incremented to the data immediately following the returned value.
}
function wav_in_i16u (                 {get unsigned 16 bit integer WAV file value}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to value, will be incremented}
  :int8u_t;                            {returned 0-65535 value}
  val_param; internal;

var
  v: int16u_t;

begin
  v := wav_in_byte (wavin, p);         {get low byte}
  v := v ! lshft(wav_in_byte (wavin, p), 8); {merge in byte 1}
  wav_in_i16u := v;                    {pass back result}
  end;
{
****************************************************************************
*
*   Function WAV_IN_I16S (WAVIN, P)
*
*   Returns the 16 bit signed integer value in the WAV file at P.  P will
*   be incremented to the data immediately following the returned value.
}
function wav_in_i16s (                 {get signed 16 bit integer WAV file value}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to value, will be incremented}
  :int16u_t;                           {returned -32768 to 32767 value}
  val_param; internal;

var
  v: integer16;

begin
  v := wav_in_byte (wavin, p);         {get low byte}
  v := v ! lshft(wav_in_byte (wavin, p), 8); {merge in byte 1}
  wav_in_i16s := v;                    {pass back result}
  end;
{
****************************************************************************
*
*   Function WAV_IN_I32U (WAVIN, P)
*
*   Returns the 32 bit unsigned integer value in the WAV file at P.  P will
*   be incremented to the data immediately following the returned value.
}
function wav_in_i32u (                 {get unsigned 32 bit integer WAV file value}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr)                 {pointer to value, will be incremented}
  :int32u_t;                           {returned 0 to 2**32-1 value}
  val_param; internal;

var
  v: int32u_t;

begin
  v := wav_in_byte (wavin, p);         {get low byte}
  v := v ! lshft(wav_in_byte (wavin, p), 8); {merge in byte 1}
  v := v ! lshft(wav_in_byte (wavin, p), 16); {merge in byte 2}
  v := v ! lshft(wav_in_byte (wavin, p), 24); {merge in byte 3}
  wav_in_i32u := v;                    {pass back result}
  end;
{
****************************************************************************
*
*   Function WAV_IN_STR (WAVIN, P, N, STR)
*
*   Return the WAV file string memory mapped to the address in P.  The first
*   N characters will be returned in STR.  P is updated to point to the next
*   byte after the string.
}
procedure wav_in_str (                 {get fixed length string from WAV file}
  in out  wavin: wav_in_t;             {state for reading this WAV file}
  in out  p: univ_ptr;                 {pointer to value, will be incremented}
  in      n: sys_int_machine_t;        {number of characters in the string}
  in out  str: univ string_var_arg_t); {the returned string}
  val_param; internal;

var
  i: sys_int_machine_t;                {loop counter}

begin
  str.len := 0;                        {init returned string to empty}
  for i := 1 to n do begin             {once for each character in the string}
    string_append1 (str, chr(wav_in_byte (wavin, p)));
    end;
  end;
{
****************************************************************************
*
*   Function WAV_IN_ITERP_CHAN (WAVIN, T, ITERP, CHAN)
*
*   Get the value of the WAV input signal interpolated at time T seconds.
*   The data time starts at zero at the start of the input signal.  ITERP
*   selects the interpolation mode.  The supported interpolation modes
*   are:
*
*     WAV_ITERP_PICK_K - Pick value of the nearest sample.
*
*     WAV_ITERP_LIN_K - Linearly interpolate between the two nearest
*       samples.
*
*     WAV_ITERP_CUBIC_K - Cubically interpolate between the nearest
*       four samples, two on each side of the interpolation point.
*
*   CHAN is the 0-N number of the data channel to return the value of.
*   The special CHAN value of -1 returns the average of all the data
*   channels.
}
function wav_in_iterp_chan (           {get interpolated WAV input signal}
  in out  wavin: wav_in_t;             {state for reading WAV input signal}
  in      t: real;                     {WAV input time at which to interpolate}
  in      iterp: wav_iterp_k_t;        {interpolation mode to use}
  in      chan: sys_int_machine_t)     {0-N channel number, -1 to average all}
  :real;                               {interpolated WAV value at T}
  val_param;

var
  s: sys_int_machine_t;                {number of first sample at or before T}
  v0, v1, v2, v3: real;                {raw values at successive sample points}
  f: real;                             {fraction T is into S to S+1 interval}
  a, b, c, d: real;                    {interpolation function coefficients}

begin
  f := t * wavin.info.srate;           {convert time to continuous sample number}
  s := round(f - 0.5);                 {sample number just before interpolation pnt}
  f := f - s;                          {fraction into interval from S to S+1}
  case iterp of                        {different code for each interpolation mode}
{
**********
*
*   Pick nearest interpolation mode.
}
wav_iterp_pick_k: begin
  if f >= 0.5 then s := s + 1;         {more than half way to next sample ?}
  wav_in_iterp_chan :=                 {return value of the selected sample}
    wav_in_samp_chan (wavin, s, chan);
  end;
{
**********
*
*   Cubic interpolation mode.
}
wav_iterp_cubic_k: begin
  v0 := wav_in_samp_chan (wavin, s - 1, chan); {get values at the control points}
  v1 := wav_in_samp_chan (wavin, s    , chan);
  v2 := wav_in_samp_chan (wavin, s + 1, chan);
  v3 := wav_in_samp_chan (wavin, s + 2, chan);

  a := -0.5*v0 + 1.5*v1 - 1.5*v2 + 0.5*v3; {make polynomial coefficients}
  b :=      v0 - 2.5*v1 + 2.0*v2 - 0.5*v3;
  c := 0.5 * (v2 - v0);
  d := v1;

  wav_in_iterp_chan :=                 {compute polynomial and return the result}
    ((a*f + b)*f + c)*f + d;
  end;
{
**********
*
*   Linear interpolation mode.  This mode is also used if the interpolation
*   mode is not recognized.
}
otherwise
    v0 := wav_in_samp_chan (wavin, s, chan); {get value at first sample}
    v1 := wav_in_samp_chan (wavin, s + 1, chan); {get value at second sample}
    wav_in_iterp_chan :=               {do the interpolation and pass back the value}
      v0 * (1.0 - f) + v1 * f;
    end;
  end;
