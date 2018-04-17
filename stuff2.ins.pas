{   Private include file for STUFF library.
}
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'stuff.ins.pas';

type
  wav_fmt_t = record                   {data from WAV "fmt" chunk}
    size: int32u_t;                    {size of remainder of the chunk}
    data_p: univ_ptr;                  {pointer to start of raw data in memory}
    dsize: sys_int_adr_t;              {size of data in bytes}
    nsamp: sys_int_machine_t;          {number of samples in the raw data}
    data_end_p: univ_ptr;              {points to first adr past end of raw data}
    dtype: integer16;                  {data type, 1 = uncompressed}
    n_chan: int16u_t;                  {number of audio channels}
    samp_sec: int32u_t;                {number of samples frames per second}
    bytes_sec: int32u_t;               {number of bytes per second}
    bytes_samp: int16u_t;              {bytes per sample frame}
    bytes_sampp: sys_int_adr_t;        {bytes per individual sample point}
    bits_samp: int16u_t;               {bits per individual sample point}
    more_p: univ_ptr;                  {pointer to additional WAV FMT data, if any}
    end;
