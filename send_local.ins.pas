{   This include file defines local routines for sending bytes to some remote
*   device.  The routines here fill up and manage the output buffer OUTBUF.  The
*   actual sending of the contents of OUTBUF must be implemented by the
*   application by supplying routine SENDALL.
*
*   The following must be defined by the application outside this file:
*
*     OUTBUF_SIZE
*
*       Number of bytes the output buffer can hold.  SENDALL is called whenever
*       the output buffer fills up.
*
*     SENDALL
*
*       Subroutine to send the contents of OUTBUF.  This routine takes no
*       parameters.  It must reset OUTBUF to empty.  The output lock must be
*       held when SENDALL is called.
*
*   The facilities from this file that applications are intended to interact
*   with are listed here.  See header comments of routines for more details.
*
*     SEND_INIT
*
*       Must be called once before any other resources from this file are used.
*
*     SEND_LOW_HIGH
*
*       Multi-byte data items will be sent in low to high byte order.  This is
*       the default after SEND_INIT.
*
*     SEND_HIGH_LOW
*
*       Multi-byte data items will be sent in high to low byte order.
*
*     SEND_ACQUIRE
*
*       Acquires exclusive lock on the sending routines.
*
*     SENDB (B)
*
*       Sends the byte B.
*
*     SENDW (W)
*
*       Sends the 16 bit word W.
*
*     SEND3 (II)
*
*       Sends the 3 byte integer II.
*
*     SEND4 (II)
*
*       Sends the 4 byte integer II.
*
*     SEND_STR (S)
*
*       Sends the characters of the var string S.
*
*     SEND_RELEASE
*
*       Release the exclusive lock on the sending routines that was acquired by
*       SEND_ACQUIRE.
*
*     SEND_FP32F (FP)
*
*       Send the floating point value FP in Embed dsPIC fast 32 bit format.
}
procedure sendall;
  val_param; forward;

type
  outbuf_t = record                    {output buffer, compatible with var string}
    max: string_index_t;
    len: string_index_t;
    str: array[1..outbuf_size] of char;
    end;

  send_local_t = record                {additional state private to these routines}
    high_low: boolean;                 {send in high to low byte order}
    lock: sys_sys_threadlock_t;        {multi-thread interlock}
    end;

var
  outbuf: outbuf_t;                    {var string output buffer}
  send_local: send_local_t;            {additional private state}
{
********************************************************************************
*
*   Subroutine SEND_INIT
*
*   This routine must be called before any other routines in this file are
*   called.
}
procedure send_init;
  val_param; internal;

var
  stat: sys_err_t;

begin
  outbuf.max := size_char(outbuf.str); {init OUTBUF}
  outbuf.len := 0;
  send_local.high_low := false;        {init to least significant byte first}
  sys_thread_lock_create (send_local.lock, stat); {create multi-thread interlock}
  sys_error_abort (stat, '', '', nil, 0);
  end;
{
********************************************************************************
*
*   Subroutine SEND_LOW_HIGH
*
*   Multi-byte fields will be sent in least to most significant byte order.
}
procedure send_low_high;
  val_param; internal;

begin
  send_local.high_low := false;
  end;
{
********************************************************************************
*
*   Subroutine SEND_HIGH_LOW
*
*   Multi-byte fields will be sent in most to least significant byte order.
}
procedure send_high_low;
  val_param; internal;

begin
  send_local.high_low := true;
  end;
{
********************************************************************************
*
*   Subroutine SEND_ACQUIRE
*
*   Acquire exclusive access to these SEND routines.
}
procedure send_acquire;                {acquire exclusive lock on stream to unit}
  val_param;

begin
  sys_thread_lock_enter (send_local.lock);
  end;
{
********************************************************************************
*
*   Subroutine SEND_RELEASE
*
*   Release exclusive access to these SEND routines.
}
procedure send_release;                {release lock on stream to remote unit}
  val_param;

begin
  sys_thread_lock_leave (send_local.lock);
  end;
{
********************************************************************************
*
*   Subroutine SENDB (B)
*
*   Send the byte in the low 8 bits of B to the remote unit.
*
*   The output lock must be held when this routine is called.
}
procedure sendb (                      {send byte to remote unit}
  in      b: sys_int_machine_t);       {byte to send in low 8 bits}
  val_param;

begin
  string_append1 (outbuf, chr(b));     {add byte to end of output buffer}

  if outbuf.len >= outbuf.max then begin {the buffer just filled up ?}
    sendall;                           {send the full buffer now, reset buffer to empty}
    end;
  end;
{
********************************************************************************
*
*   Subroutine SENDW (W)
*
*   Send the word in the low 16 bits of W to the remote unit.
*
*   The output lock must be held when this routine is called.
}
procedure sendw (                      {send 16 bit word to remote unit}
  in      w: sys_int_machine_t);       {word to send in low 16 bits}
  val_param;

begin
  if send_local.high_low
    then begin
      sendb (rshft(w, 8));                 {send the high byte}
      sendb (w);                           {send the low byte}
      end
    else begin
      sendb (w);                           {send the low byte}
      sendb (rshft(w, 8));                 {send the high byte}
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine SEND3 (I)
*
*   Send the 3-byte value in the low 32 bits of I to the remote unit.  The bytes
*   are send in the normal least to most significant order.
*
*   The output lock must be held when this routine is called.
}
procedure send3 (                      {send 4 byte word to remote unit}
  in      i: sys_int_conv32_t);        {word to send in low 32 bits}
  val_param;

begin
  if send_local.high_low
    then begin
      sendb (rshft(i, 16));
      sendb (rshft(i, 8));
      sendb (i);
      end
    else begin
      sendb (i);
      sendb (rshft(i, 8));
      sendb (rshft(i, 16));
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine SEND4 (I)
*
*   Send the value in the low 32 bits of I to the remote unit.  The bytes are
*   send in the normal least to most significant order.
*
*   The output lock must be held when this routine is called.
}
procedure send4 (                      {send 4 byte word to remote unit}
  in      i: sys_int_conv32_t);        {word to send in low 32 bits}
  val_param;

begin
  if send_local.high_low
    then begin
      sendb (rshft(i, 24));
      sendb (rshft(i, 16));
      sendb (rshft(i, 8));
      sendb (i);
      end
    else begin
      sendb (i);
      sendb (rshft(i, 8));
      sendb (rshft(i, 16));
      sendb (rshft(i, 24));
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine SEND_STR (S)
*
*   Send the characters of the string S to the remote unit.  Only the string
*   body is sent without length, terminating NULL, etc.
*
*   The output lock must be held when this routine is called.
}
procedure send_str (                   {send string to remote unit}
  in      s: univ string_var_arg_t);   {string to send body of}
  val_param;

var
  i: sys_int_machine_t;                {loop counter}

begin
  for i := 1 to s.len do begin         {once for each character in the string}
    sendb (ord(s.str[i]));
    end;
  end;
{
********************************************************************************
*
*   Subroutine SEND_FP32F (FP)
*
*   Send the floating point value FP in Embed Inc dsPIC fast 32 bit format.
}
procedure send_fp32f (                 {send floating point in FP32F format}
  in      fp: double);                 {the floating point value to send}
  val_param;

var
  f32: pic_fp32f_t;                    {FP value in output format}
  tk: string_var32_t;

begin
  f32 := pic_fp32f_f_real (fp);        {convert to PIC format}
  if send_local.high_low
    then begin                         {send in most to least significant order}
      sendw (f32.w1);
      sendw (f32.w0);
      end
    else begin                         {send in least to most significant order}
      sendw (f32.w0);
      sendw (f32.w1);
      end
    ;
  end;
