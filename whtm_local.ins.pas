{   This include file defines local routines for writing to a HTML output file.
*   These routines are simplified wrappers around the general HTM writing
*   routines HTM_WRITE_xxx in the STUFF include file.  The following
*   simplifications are made:
*
*     1 - The HTML writing state is HOUT.
*
*     2 - The program is aborted on any error.
*
*   The subroutines exported by this file are:
*
*     WHTM_INDENT                      +1 indentation level
*     WHTM_UNDENT                      -1 indentation level
*     WHTM_INDENT_REL (N)              relative indentation level change
*     WHTM_INDENT_ABS (N)              1-N absolute indentation level
*
*     WHTM_LINE (VSTR)                 write line, var string
*     WHTM_LINE_STR (STR)              write line, Pascal string
*     WHTM_NEWLINE                     to start of next line, obeys indentation
*     WHTM_BLINE                       write blank line
*
*     WHTM_NOPAD                       no blank pad before next string
*     WHTM_WRAP (ON)                   enable/disable strings wrapping to new line
*     WHTM_VSTR (VSTR)                 write free-format string, var string
*     WHTM_STR (STR)                   write free-format string, Pascal string
*
*     WHTM_COLOR (RED, GRN, BLU)       write HTML HEX color spec, any color
*     WHTM_GRAY (GRAY)                 write HTML HEX color spec, gray level
*
*     WHTM_PRE_START                   start pre-formatted text
*     WHTM_PRE_LINE (VSTR)             write pre-formatted line
*     WHTM_PRE_END                     end pre-formatted text
*
*     WHTM_BUF                         write any buffered data
}

{*******************************************************************************
}
procedure whtm_indent;
  val_param; internal;

begin
  htm_write_indent_rel (hout, 1);
  end;

{*******************************************************************************
}
procedure whtm_undent;
  val_param; internal;

begin
  htm_write_indent_rel (hout, -1);
  end;

{*******************************************************************************
}
procedure whtm_indent_rel (
  in      n: sys_int_machine_t);
  val_param; internal;

begin
  htm_write_indent_rel (hout, n);
  end;

{*******************************************************************************
}
procedure whtm_indent_abs (
  in      n: sys_int_machine_t);
  val_param; internal;

begin
  htm_write_indent_abs (hout, n);
  end;

{*******************************************************************************
}
procedure whtm_line (
  in      line: univ string_var_arg_t);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_line (hout, line, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_line_str (
  in      line: string);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_line_str (hout, line, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_bline;
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_bline (hout, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_nopad;
  val_param; internal;

begin
  htm_write_nopad (hout);
  end;

{*******************************************************************************
}
procedure whtm_wrap (
  in      on: boolean);
  val_param; internal;

begin
  htm_write_wrap (hout, on);
  end;

{*******************************************************************************
}
procedure whtm_vstr (
  in      str: univ string_var_arg_t);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_vstr (hout, str, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_str (
  in      str: string);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_str (hout, str, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_color (
  in      red, grn, blu: real);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_color (hout, red, grn, blu, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_gray (
  in      gray: real);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_color_gray (hout, gray, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_newline;
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_newline (hout, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_pre_start;
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_pre_start (hout, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_pre_line (
  in      line: univ string_var_arg_t);
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_pre_line (hout, line, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_pre_end;
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_pre_end (hout, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;

{*******************************************************************************
}
procedure whtm_buf;
  val_param; internal;

var
  stat: sys_err_t;

begin
  htm_write_buf (hout, stat);
  sys_error_abort (stat, '', '', nil, 0);
  end;
