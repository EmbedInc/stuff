{   Module of routines for reading WAV files.  These routines are exported
*   in the STUFF library.
}
module wav_filt;
define wav_filt_init;
define wav_filt_aa;
define wav_filt_val;
define wav_filt_samp_chan;
%include 'stuff2.ins.pas';
{
****************************************************************************
*
*   Subroutine WAV_FILT_INIT (WAVIN, TMIN, TMAX, FFREQ, FILT)
*
*   Initialize the WAV input filtering state FILT.  WAVIN is the state for
*   reading the raw WAV input.  TMIN and TMAX are the min/max seconds range
*   of the filter convolution kernel.  FFREQ is the minimum effective sample
*   frequency with which the filter kernel is to be defined.  When the filter
*   convolution is performed, the filter kernel is linearly interpolated
*   between samples.
*
*   TMIN and TMAX are defined so that the impulse response of the filter is
*   the filter function from TMIN to TMAX.  The filter value at T = 0 will be
*   convolved with the present input signal.  The filter at positive T values
*   will be convolved with past input values and those at negative T values
*   with future input values.  The filter kernel is assumed to be zero for
*   all values outside the TMIN to TMAX range.  For example, a simple R-C
*   filter is best modeled by TMIN = 0 with TMAX at some positive value
*   sufficient to achieve the desired signal to noise ratio.  TMAX must
*   be greater than TMIN.
*
*   This routine initializes the FILT descriptor, allocates memory for
*   the filter function, and initializes all filter coeficients to zero.
}
procedure wav_filt_init (              {init WAV input filter}
  in out  wavin: wav_in_t;             {state for reading WAV input stream}
  in      tmin: real;                  {seconds offset for first filter kernel point}
  in      tmax: real;                  {seconds offset for last filter kernel point}
  in      ffreq: real;                 {Hz samp freq for defining filter function}
  out     filt: wav_filt_t);           {initialized filter info, filter all zero}
  val_param;

var
  i: sys_int_machine_t;                {scratch integer and loop counter}

begin
  filt.wavin_p := addr(wavin);         {save pointer to WAV input state}
  filt.np := trunc((tmax - tmin) * ffreq + 1.0); {make number of filter points}
  filt.dp := 1.0 / ffreq;              {period filter kernel sampled at}
  if filt.np < 2
    then begin                         {not enough filter points, don't filter}
      filt.np := 1;
      filt.t0 := (tmin + tmax) * 0.5;
      end
    else begin                         {at least two filt pnts, set up for filtering}
      filt.t0 := tmin;                 {T of first filter point}
      end
    ;
  util_mem_grab (                      {allocate memory for the filter function}
    sizeof(filt.kern_p^[0]) * filt.np, {amount of memory to allocate}
    wavin.mem_p^,                      {parent memory context}
    true,                              {may need to individually deallocate}
    filt.kern_p);                      {returned pointer to the new memory}
  filt.plast := filt.np - 1;           {0-N index of last filter point}
  filt.ugain := true;                  {init to adjust filter output for unity gain}

  if filt.np = 1
    then begin                         {not filtering, set one dummy filter point}
      filt.kern_p^[0] := 1.0;
      end
    else begin                         {filtering enabled, init all points to zero}
      for i := 0 to filt.plast do begin {once for each filter point}
        filt.kern_p^[i] := 0.0;        {init all filter points to zero}
        end;
      end
    ;
  end;
{
****************************************************************************
*
*   Subroutine WAV_FILT_AA (WAVIN, FCUT, ATTCUT, FILT)
*
*   Set up a filter for the purpose of re-sampling the input WAV data to
*   a different frequency.  The filter will be low pass with a minimum
*   attenuation of ATTCUT at the frequency FCUT.  Normally, FCUT would
*   1/2 the new sample rate and ATTCUT would be the maximum tolerable
*   noise/signal ratio.
*
*   ***  NOTE  ***
*   This version ignores ATTCUT and sets up a SINC function with fixed
*   parameters that works well enough for most cases.
}
procedure wav_filt_aa (                {set up anti-aliasing filter}
  in out  wavin: wav_in_t;             {state for reading WAV input stream}
  in      fcut: real;                  {cutoff frequency, herz}
  in      attcut: real;                {min required attenuation at cutoff freq}
  out     filt: wav_filt_t);           {returned initialized filter info}
  val_param;

const
  cutf = 0.85;                         {SINC cutoff frequency relative to FCUT}
  ppc = 32.0;                          {number of filter points per SINC cycle}
  nsc = 35;                            {number of SINC cycles each side of zero}

var
  sfreq: real;                         {frequency of the SINC function}
  tlen: real;                          {time length of SINC from 0 to either end}
  m: real;                             {conversion from filter time to SINC arg}
  t: real;                             {filter kernel time}
  r: real;                             {scratch floating point value}
  sine: real;                          {SINE value at current point}
  sinc: real;                          {SINC value at current point}
  i: sys_int_machine_t;                {scratch integer and loop counter}

begin
  if fcut >= (wavin.info.srate * 0.49999) then begin {no need to filter ?}
    wav_filt_init (                    {initialize FILT descriptor}
      wavin,                           {WAV input reading state}
      0.0, 0.0,                        {set time span to disable filtering}
      fcut * 2.0,                      {sample frequency for defining filter kernel}
      filt);                           {returned initialized filter descriptor}
    return;
    end;

  sfreq := fcut * cutf;                {make cutoff frequency of the SINC function}
  tlen := nsc / sfreq;                 {time from center to end of SINC kernel}

  wav_filt_init (                      {initialize FILT descriptor}
    wavin,                             {WAV input reading state}
    -tlen, tlen,                       {filter kernel time span}
    sfreq * ppc,                       {sample frequency for defining filter kernel}
    filt);                             {returned initialized filter descriptor}

  m := 2.0 * pi * sfreq;               {scale from kernel time to SINC argument}
  for i := 0 to filt.plast do begin    {once for each filter kernel point}
    t := i * filt.dp + filt.t0;        {make filter kernel time at this point}
    r := t * m;                        {make SIN(X)/X argument at this point}
    if abs(r) > 1.0E-5                 {solve for SINC function value}
      then begin                       {not the special case at 0}
        sine := sin(r);
        sinc := sine / r;
        end
      else begin                       {substitute limit of function at 0}
        sinc := 1.0;
        end
      ;
    filt.kern_p^[i] := sinc;           {set value of this filter kernel point}
    end;
  end;
{
****************************************************************************
*
*   Function WAV_FILT_VAL (FILT, T)
*
*   Returns the filter kernel value interpolated to filter time T.  During
*   use, the filter at positive T values will be convolved with past input
*   samples, and those a negative T values with future input samples.
}
function wav_filt_val (                {get interpolated filter kernel value}
  in out  filt: wav_filt_t;            {info for filtering WAV input stream}
  in      t: real)                     {filter time, pos for past, neg for future}
  :real;                               {filter kernel interpolated to filter time T}
  val_param;

var
  st: real;                            {continuous filter sample number at T}
  s1, s2: sys_int_machine_t;           {filter kernel samples numbers}
  v1, v2: real;                        {filter values at S1 and S2}
  m2: real;                            {interpolation weighting fraction for V2}

begin
  wav_filt_val := 0.0;                 {init return value for out of filter range}

  st := (t - filt.t0) / filt.dp;       {convert T to sample number space}
  s1 := round(st - 0.5);               {make low sample number for interpolation}
  if s1 > filt.plast then return;      {past end of filter, return zero ?}
  s2 := s1 + 1;                        {make high sample number for interpolation}
  if s2 < 0 then return;               {before start of filter, return zero ?}

  if s1 >= 0                           {set V1 to the filter value at sample S1}
    then v1 := filt.kern_p^[s1]
    else v1 := 0.0;
  if s2 <= filt.plast                  {set V2 to the filter value at sample S2}
    then v2 := filt.kern_p^[s2]
    else v2 := 0.0;

  m2 := st - s1;                       {make weighting factor for V2}
  wav_filt_val :=                      {do the interpolation and pass back result}
    v1 * (1.0 - m2) + v2 * m2;
  end;
{
****************************************************************************
*
*   Function WAV_FILT_SAMP_CHAN (FILT, T, CHAN)
*
*   Filter the WAV input to produce the filtered value at time T.  T is in
*   seconds, and starts at 0 at the start of the WAV input.  CHAN is the
*   channel number to return the filtered value of.  Channels are numbered
*   0-N.  The special channel value of -1 causes all the channels to be
*   averaged for each WAV input data point before being applied to the
*   filter.
}
function wav_filt_samp_chan (          {get filtered value of channel in sample}
  in out  filt: wav_filt_t;            {info for filtering WAV input stream}
  in      t: real;                     {WAV input time at which to create sample}
  in      chan: sys_int_machine_t)     {0-N channel number, -1 to average all}
  :real;                               {-1 to +1 sample value}
  val_param;

var
  acc: double;                         {accumulated convolution value}
  accf: double;                        {accumulated total filter weight}
  s1, s2: sys_int_machine_t;           {start and end input WAV samples in interval}
  s: sys_int_machine_t;                {current input sample number}
  r: real;                             {scratch floating point value}
  v: real;                             {input sample value}
  wdt: real;                           {seconds between WAV samples}

begin
  if filt.np <= 1 then begin           {filtering is disabled ?}
    wav_filt_samp_chan := wav_in_iterp_chan ( {pass back interpolated input signal}
      filt.wavin_p^,                   {WAV input reading state}
      t - filt.t0,                     {time at which to interpolate input signal}
      wav_iterp_cubic_k,               {select interpolation mode}
      chan);
    return;
    end;

  wav_filt_samp_chan := 0.0;           {init return value for out of bounds cases}

  wdt := 1.0 / filt.wavin_p^.info.srate; {make seconds between WAV data points}

  r := t - (filt.t0 + filt.np * filt.dp); {start time of convolution interval}
  s1 := trunc(r * filt.wavin_p^.info.srate + 1.0); {make interval start sample num}
  if s1 > filt.wavin_p^.salast then return; {past end of all input samples ?}

  r := t - filt.t0;                    {end time of convolution interval}
  s2 := trunc(r * filt.wavin_p^.info.srate); {make interval end sample num}
  if s2 < 0 then return;               {before start of all input samples ?}
  if s2 < s1 then return;              {no useable input samples exist ?}

  acc := 0.0;                          {init convolution accumulator}
  accf := 0.0;                         {init accumulated filter weight}
  for s := s1 to s2 do begin           {once for each input sample in convolution}
    r := t - s * wdt;                  {make filter time at this input sample}
    r := wav_filt_val (filt, r);       {get filter kernel value at this input sample}
    accf := accf + r;                  {update total filter weight}
    if (s >= 0) and (s <= filt.wavin_p^.salast)
      then begin                       {this input sample exists ?}
        v := wav_in_samp_chan (filt.wavin_p^, s, chan); {get this input sample}
        end
      else begin                       {this input sample is outside the data}
        v := 0.0;
        end
      ;
    acc := acc + v * r;                {add in weighted contribution from this samp}
    end;

  if filt.ugain then begin             {normalize filter to unity gain ?}
    if abs(accf) > 1.0E-6 then begin   {total filter weight was non-zero ?}
      acc := acc / accf;               {adjust output for total filter area}
      end;
    end;

  wav_filt_samp_chan := acc;           {pass back final result}
  end;
