{   Module of routines for writing WAV files.  These routines are exported
*   in the STUFF library.
}
module wav_out;
define wav_out_open_fnam;
define wav_out_close;
define wav_out_samp;
define wav_out_samp_mono;
%include 'stuff2.ins.pas';
{
*   Private routines used inside this module only.
}
procedure wav_out_buf (                {write buffered data to WAV file, reset buff}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;

procedure wav_out_i8 (                 {write one 8 bit byte to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: sys_int_conv8_t;        {the value to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;

procedure wav_out_str (                {write string of bytes to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      str: univ string;            {the array of bytes to write}
  in      len: sys_int_adr_t;          {the number of bytes to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;

procedure wav_out_i16 (                {write 16 bit integer to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: sys_int_conv16_t;       {the value to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;

procedure wav_out_i32 (                {write 32 bit integer to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: sys_int_conv32_t;       {the value to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;

procedure wav_out_header (             {write all the header info before raw data}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;

procedure wav_out_chan (               {write the value for a single channel}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: real;                   {-1 to +1 value for the channel}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal; forward;
{
****************************************************************************
*
*   Subroutine WAV_OUT_OPEN_FNAM (WAVOT, FNAM, INFO, STAT)
*
*   Open a WAV file for writing.  WAVOT is the state for writing to the WAV
*   file, and must be passed to the other WAV_OUT_xxx routines.  INFO
*   describes how the WAV data is to be formatted.  The following fields
*   in INFO must be filled in:
*
*     ENC  -  Encoding format.  Supported formats are:
*
*       WAV_ENC_SAMP_K  -  Uncompressed samples at regular intervals.
*
*     NCHAN  -  Number of audio channels.  1 for mono, 2 for stereo, etc.
*
*     SRATE  -  Sample rate in Hz.
*
*     CBITS  -  Number of bits per sample per channel.  This value will
*       be rounded up to either 8 or 16 before use.
*
*   The remaining fields in INFO are ignored.  WAVOT.INFO will be set to the
*   values actually used.
}
procedure wav_out_open_fnam (          {open WAV output file by name}
  out     wavot: wav_out_t;            {returned state for this use of WAV_OUT calls}
  in      fnam: univ string_treename_t; {output file name}
  in      info: wav_info_t;            {info about the WAV data}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

begin
  case info.enc of                     {what encoding type is requested}
wav_enc_samp_k: ;                      {uncompressed samples at regular intevals}
otherwise                              {unsupported WAV file encoding method}
    sys_stat_set (stuff_subsys_k, stuff_stat_wavencr_k, stat);
    sys_stat_parm_int (ord(info.enc), stat);
    return;
    end;

  file_open_write_bin (                {open output file for binary write}
    fnam, '.wav', wavot.conn, stat);
  if sys_error(stat) then return;

  wavot.info.enc := info.enc;          {save encoding method ID}
  wavot.info.nchan := min(wav_chan_max_k, info.nchan); {save number of channels}
  wavot.info.srate := info.srate;      {save sample rate in Hz}
  wavot.info.cbits := 8;               {init bits per channel value}
  if info.cbits > 8 then begin         {need more than 8 bits ?}
    wavot.info.cbits := 16;            {use 16 bits}
    end;
  wavot.info.cbytes := wavot.info.cbits div 8; {number of bytes required per value}
  wavot.info.sbytes := wavot.info.cbytes * wavot.info.nchan; {bytes per whole sample}
  wavot.nsamp := 0;                    {init number of samples written so far}
  wavot.salast := -1;
  wavot.chlast := wavot.info.nchan - 1; {indicate the 0-N number of the last channel}
  wavot.bufn := 0;                     {init to output buffer is empty}
{
*   The header is written here only to reserve the correct amount of space
*   for it.  The header is re-written after all the data has been written
*   so when all the fields can be filled in correctly.
}
  wav_out_header (wavot, stat);        {write bogus header just to position the file}
  if sys_error(stat) then begin
    file_close (wavot.conn);
    end;
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_CLOSE (WAVOT, STAT)
*
*   Close the WAV output file and end this use of the WAV_OUT_xxx routines.
*   WAVOT is returned invalid.
}
procedure wav_out_close (              {close WAV output file}
  in out  wavot: wav_out_t;            {state for writing WAV file, returned invalid}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  pos: file_pos_t;                     {file position at end of all data}

begin
  wav_out_buf (wavot, stat);           {write any buffered data to the output file}
  if sys_error(stat) then return;

  file_pos_get (wavot.conn, pos);      {save file position at the end of all data}
  file_pos_start (wavot.conn, stat);   {move to the start of the WAV file}
  if sys_error(stat) then return;
  wav_out_header (wavot, stat);        {write WAV file header now all info is known}
  if sys_error(stat) then return;
  wav_out_buf (wavot, stat);           {make sure all data actually written to file}
  if sys_error(stat) then return;
  file_pos_set (pos, stat);            {restore position to the end of all the data}
  if sys_error(stat) then return;

  file_close (wavot.conn);             {close WAV output, truncate at curr position}
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_BUF (WAVOT, STAT)
*
*   Write all the previously buffered data to the output file and reset the
*   buffer to empty.  This call does nothing if the buffer is already empty.
}
procedure wav_out_buf (                {write buffered data to WAV file, reset buff}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

begin
  if wavot.bufn <= 0 then begin        {the buffer is already empty ?}
    sys_error_none (stat);
    return;
    end;

  file_write_bin (wavot.buf, wavot.conn, wavot.bufn, stat); {write buffer to file}
  wavot.bufn := 0;                     {reset the buffer to empty}
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_I8 (WAVOT, VAL, STAT)
*
*   Write the 8 bit integer in VAL to the output.
}
procedure wav_out_i8 (                 {write one 8 bit byte to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: sys_int_conv8_t;        {the value to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

begin
  sys_error_none (stat);               {init to no error encountered}

  if wavot.bufn >= sizeof(wavot.buf) then begin {buffer is full ?}
    wav_out_buf (wavot, stat);         {write the buffer to the output file}
    if sys_error(stat) then return;
    end;

  wavot.buf[wavot.bufn] := chr(val);   {stuff the byte into the output buffer}
  wavot.bufn := wavot.bufn + 1;        {count one more byte in the output buffer}
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_STR (WAVOT, STR, LEN, STAT)
*
*   Write a string to the output.  STR is the string and LEN is the number
*   of bytes in the string.
}
procedure wav_out_str (                {write string of bytes to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      str: univ string;            {the array of bytes to write}
  in      len: sys_int_adr_t;          {the number of bytes to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

var
  i: sys_int_machine_t;                {loop counter}

begin
  sys_error_none (stat);               {init to no error encountered}

  for i := 1 to len do begin           {once for each byte in the string}
    wav_out_i8 (wavot, ord(str[i]), stat); {write this byte to the output}
    if sys_error(stat) then return;
    end;
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_I16 (WAVOT, VAL, STAT)
*
*   Write the 16 bit integer in VAL to the output.
}
procedure wav_out_i16 (                {write 16 bit integer to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: sys_int_conv16_t;       {the value to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

begin
  wav_out_i8 (wavot, val & 255, stat); {write bytes in low to high order}
  if sys_error(stat) then return;
  wav_out_i8 (wavot, rshft(val, 8) & 255, stat);
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_I32 (WAVOT, VAL, STAT)
*
*   Write the 32 bit integer in VAL to the output.
}
procedure wav_out_i32 (                {write 32 bit integer to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: sys_int_conv32_t;       {the value to write}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

begin
  wav_out_i8 (wavot, val & 255, stat); {write bytes in low to high order}
  if sys_error(stat) then return;
  wav_out_i8 (wavot, rshft(val, 8) & 255, stat);
  if sys_error(stat) then return;
  wav_out_i8 (wavot, rshft(val, 16) & 255, stat);
  if sys_error(stat) then return;
  wav_out_i8 (wavot, rshft(val, 24) & 255, stat);
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_HEADER (WAVOT, STAT)
*
*   Write all the header info of a WAV file.  The raw data immediately follows
*   this header.
}
procedure wav_out_header (             {write all the header info before raw data}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

const
  fmt_size_k = 24;                     {bytes in whole "fmt" chunk for uncompressed}

var
  i: sys_int_conv32_t;                 {scratch integer}

begin
  wav_out_str (wavot, 'RIFF', 4, stat); {RIFF chunk name}
  if sys_error(stat) then return;
  wav_out_i32 (wavot,                  {bytes in remainder of whole RIFF chunk}
    4 +                                {WAVE chunk}
    fmt_size_k +                       {size of whole "fmt " chunk}
    8 +                                {DATA chunk name and length}
    wavot.info.sbytes * wavot.nsamp,   {number of raw data bytes}
    stat);
  if sys_error(stat) then return;

  wav_out_str (wavot, 'WAVE', 4, stat); {WAVE chunk name}
  if sys_error(stat) then return;

  wav_out_str (wavot, 'fmt ', 4, stat); {FMT chunk name}
  if sys_error(stat) then return;
  wav_out_i32 (wavot, fmt_size_k - 8, stat); {size of rest of FMT chunk}
  if sys_error(stat) then return;
  wav_out_i16 (wavot, 1, stat);        {format ID, 1 = uncompressed}
  if sys_error(stat) then return;
  wav_out_i16 (wavot, wavot.info.nchan, stat); {number of channels}
  if sys_error(stat) then return;
  i := trunc(wavot.info.srate + 0.5);  {sample rate to write to WAV file}
  wav_out_i32 (wavot, i, stat);        {sample frames per second}
  if sys_error(stat) then return;
  wav_out_i32 (wavot, i * wavot.info.sbytes, stat); {bytes per second}
  if sys_error(stat) then return;
  wav_out_i16 (wavot, wavot.info.sbytes, stat); {bytes per sample}
  if sys_error(stat) then return;
  wav_out_i16 (wavot, wavot.info.cbits, stat); {bits per sample per channel}
  if sys_error(stat) then return;

  wav_out_str (wavot, 'data', 4, stat); {DATA chunk name}
  if sys_error(stat) then return;
  wav_out_i32 (wavot,                  {size of rest of DATA chunk}
    wavot.info.sbytes * wavot.nsamp, stat);
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_CHAN (WAVOT, VAL, STAT)
*
*   Write the value of a single channel to the output.  VAL is the channel
*   value in -1 to +1 format.
}
procedure wav_out_chan (               {write the value for a single channel}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: real;                   {-1 to +1 value for the channel}
  out     stat: sys_err_t);            {returned completion status code}
  val_param; internal;

var
  v: real;                             {channel value clipped to valid range}
  i: sys_int_conv32_t;                 {scratch integer}

begin
  v := max(-1.0, min(1.0, val));       {make channel value clipped to legal range}

  case wavot.info.cbits of             {how many bits per output channel value ?}
8:  begin                              {channel value is unsigned 8 bit integer}
      i := trunc(v * 128.0 + 128.0);   {make 0-255 integer}
      i := max(0, min(255, i));
      wav_out_i8 (wavot, i, stat);     {write converted value to the WAV file}
      end;
16: begin                              {channel value is signed 16 bit integer}
      i := trunc(v * 32768.0);         {make -32768 to 32767 integer}
      i := max(-32768, min(32767, i));
      wav_out_i16 (wavot, i, stat);    {write converted value to the WAV file}
      end;
otherwise
    writeln ('*** INTERNAL ERROR ***');
    writeln ('WAV_OUT_CHAN in WAV_OUT module called with CBITS = ',
       wavot.info.cbits);
    sys_bomb;
    end;
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_SAMP (WAVOT, CHANS, NCHAN, STAT)
*
*   Write a sample point to the WAV file.  The data for each channel is
*   in the CHANS array.  The valid range of CHANS values is from -1 to +1.
*   NCHAN indicates the number of values supplied in the CHANS array.
*   Output channels for which no values are passed in CHANS are set to
*   zero.  Data for additional output channels not in the WAV file is
*   ignored.
}
procedure wav_out_samp (               {write next sample to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      chans: univ wav_samp_t;      {-1 to 1 data for each chan within the sample}
  in      nchan: sys_int_machine_t;    {number of chans data supplied for in CHANS}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  i: sys_int_machine_t;                {loop counter}

begin
  sys_error_none (stat);               {init to no error encountered}

  for i := 0 to wavot.info.nchan-1 do begin {once for each output channel}
    if i < nchan
      then begin                       {CHANS contains data for this channel}
        wav_out_chan (wavot, chans[i], stat);
        end
      else begin                       {no data is available for this channel}
        wav_out_chan (wavot, 0.0, stat);
        end
      ;
    if sys_error(stat) then return;
    end;                               {back to write the data for the next channel}

  wavot.salast := wavot.nsamp;         {update state to one more sample written}
  wavot.nsamp := wavot.nsamp + 1;
  end;
{
****************************************************************************
*
*   Subroutine WAV_OUT_SAMP_MONO (WAVOT, VAL, STAT)
*
*   Write a monophonic sample to the output.  All the channel values for this
*   sample are set to VAL.  VAL must be in the -1 to +1 range.
}
procedure wav_out_samp_mono (          {write monophonic sample to WAV output file}
  in out  wavot: wav_out_t;            {state for writing this WAV file}
  in      val: real;                   {-1.0 to 1.0 value for all channels}
  out     stat: sys_err_t);            {returned completion status code}
  val_param;

var
  chans: wav_samp_t;                   {individual value for each channel}
  i: sys_int_machine_t;                {loop counter}

begin
  for i := 0 to wavot.info.nchan-1 do begin {once for each channel in WAV file}
    chans[i] := val;                   {set this channel to the monophonic value}
    end;
  wav_out_samp (wavot, chans, wavot.info.nchan, stat); {write whole sample to output}
  end;
