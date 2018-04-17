{   Read reference parts list from CSV file.
}
module partref;
define partref_read_csv;
%include 'stuff2.ins.pas';
{
********************************************************************************
*
*   Subroutine PARTREF_READ_CSV (LIST, CSVNAME, STAT)
*
*   Read the list of reference parts from the CSV file CSVNAME and add them to
*   the list LIST.
*
*   The first line of the CSV file is the header line that contains the names
*   for each of the fields.  Fields that are used by this routine must be named
*   "Desc", "Value", "Package", "Subst", "Manuf", "Manuf part #", "Supplier",
*   "Supp part #", and any number of "Inhouse xxx".  For the "Inhouse xxx"
*   names, "xxx" is the name of the organization the in-house part number is
*   for.  "Xxx" must be a single token.  If it contains blanks, then it must be
*   enclosed in quotes.  For example, valid field names are "Inhouse Acme", and
*   "Inhouse MegaCorp".
*
*   Subsequent CSV file lines must either contain data or be comment lines.
*   Comment lines are empty, contain only blanks, or have the star (*) character
*   in column 1.
*
*   The list must have been previously initialized, and may contain existing
*   entries.  New entries will be added to the list.
}
procedure partref_read_csv (           {add parts from CSV file to partref list}
  in out  list: partref_list_t;        {the list to add parts to}
  in      csvname: univ string_var_arg_t; {CSV file name, ".csv" suffix may be omitted}
  out     stat: sys_err_t);
  val_param;

const
  maxorg = 4;                          {max allowed organizations with part numbers}

type
  org_t = record                       {one organization with private part numbers}
    name: string_var32_t;              {organization name}
    field: sys_int_machine_t;          {1-N number of field part numbers are on}
    numb: string_var32_t;              {part number on current line}
    end;

var
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  conn: file_conn_t;                   {connection to the CSV file}
  buf: string_var8192_t;               {one line input buffer}
  p: string_index_t;                   {BUF parse index}
  tk, tk2: string_var132_t;            {sratch tokens}
  ptk: string_index_t;                 {TK parse index}
  pick: sys_int_machine_t;             {number of token picked from list}
  fieldn: sys_int_machine_t;           {current 1-N number of field being read}
  field_desc: sys_int_machine_t;       {field numbers for our recognized fields}
  field_val: sys_int_machine_t;
  field_pack: sys_int_machine_t;
  field_subs: sys_int_machine_t;
  field_manu: sys_int_machine_t;
  field_manun: sys_int_machine_t;
  field_supp: sys_int_machine_t;
  field_suppn: sys_int_machine_t;
  org: array[1..maxorg] of org_t;      {organizations with private part numbers}
  norg: sys_int_machine_t;             {number of organizations in list}
  val_desc: string_var132_t;           {saved values from each of the known fields}
  val_val: string_var132_t;
  val_pack: string_var32_t;
  val_subs_set: boolean;
  val_subs: boolean;
  val_manu: string_var32_t;
  val_manun: string_var80_t;
  val_supp: string_var32_t;
  val_suppn: string_var80_t;
  nvals: sys_int_machine_t;            {number of values saved this line}
  part_p: partref_part_p_t;            {pointer to partref list entry from curr line}
  namval_p: nameval_ent_p_t;           {pointer to current name/value list entry}

(*
desc
val
pack
subs
manu
manun
supp
suppn
*)

label
  err_atline, done;

begin
  buf.max := size_char(buf.str);       {init local var strings}
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);
  val_desc.max := size_char(val_desc.str);
  val_val.max := size_char(val_val.str);
  val_pack.max := size_char(val_pack.str);
  val_manu.max := size_char(val_manu.str);
  val_manun.max := size_char(val_manun.str);
  val_supp.max := size_char(val_supp.str);
  val_suppn.max := size_char(val_suppn.str);

  file_open_read_text (csvname, '.csv', conn, stat); {open the CSV file}
  if sys_error(stat) then return;
{
*   Read the header line to find out which fields are what.  The FIELD_xxx
*   variables will be set to the 1-N number of the field containing the
*   corresponding value.  A value of 0 indicates that field is not included in
*   this CSV file.
}
  file_read_text (conn, buf, stat);    {read the header line}
  if file_eof(stat) then goto done;    {end of file ?}
  if sys_error(stat) then goto done;
  p := 1;                              {init input line parse index}

  field_desc := 0;                     {init all fields to not found}
  field_val := 0;
  field_pack := 0;
  field_subs := 0;
  field_manu := 0;
  field_manun := 0;
  field_supp := 0;
  field_suppn := 0;
  for ii := 1 to maxorg do begin       {init each organization descriptor}
    org[ii].name.max := size_char(org[ii].name.str);
    org[ii].name.len := 0;
    org[ii].field := 0;
    org[ii].numb.max := size_char(org[ii].numb.str);
    org[ii].numb.len := 0;
    end;
  norg := 0;                           {init number of organizations in the list}

  fieldn := 0;                         {init to before first field}
  while true do begin                  {once for each header line field}
    string_token_comma (buf, p, tk, stat); {get this field into TK}
    if string_eos(stat) then exit;     {hit end of header line ?}
    if sys_error(stat) then goto err_atline;
    string_unpad (tk);                 {remove trailing blanks}
    fieldn := fieldn + 1;              {make the 1-N number of this field}
    string_tkpick80 (tk,
      'Desc Value Package Subst Manuf "Manuf part #" Supplier "Supp part #"',
      pick);
    case pick of                       {which field is this ?}
1:    field_desc := fieldn;
2:    field_val := fieldn;
3:    field_pack := fieldn;
4:    field_subs := fieldn;
5:    field_manu := fieldn;
6:    field_manun := fieldn;
7:    field_supp := fieldn;
8:    field_suppn := fieldn;
otherwise
      ptk := 1;                        {init TK parse index}
      string_token (tk, ptk, tk2, stat); {get first token of field name string}
      if sys_error(stat) then next;
      if not string_equal (tk2, string_v('Inhouse'(0))) then next;
      string_token (tk, ptk, tk2, stat); {get organization name into TK2}
      if sys_error(stat) then next;
      if ptk <= tk.len then next;      {more tokens left in field name ?}
      {
      *   TK2 contains the name of a new organization with private numbers.
      }
      if norg >= maxorg then begin     {no room for another organization ?}
        sys_stat_set (stuff_subsys_k, stuff_stat_partref_orgovfl_k, stat);
        sys_stat_parm_str ('partref_read_csv'(0), stat);
        sys_stat_parm_int (maxorg, stat);
        goto done;
        end;
      norg := norg + 1;                {update number of organizations}
      string_copy (tk2, org[norg].name); {save organization name}
      org[norg].field := fieldn;       {save field number for this org}
      end;                             {end of which field cases}
    end;                               {back to do next header line field}
{
*   Read the remaining lines and add their info to the partref list.
}
  while true do begin                  {back to read each new line}
    file_read_text (conn, buf, stat);  {read new CSV file line into BUF}
    if file_eof(stat) then exit;       {end of file ?}
    if sys_error(stat) then goto done; {hard error ?}
    string_unpad (buf);                {strip trailing blanks}
    if buf.len <= 0 then next;         {empty line, ignore it ?}
    if buf.str[1] = '*' then next;     {comment line, ignore it ?}
    p := 1;                            {init BUF parse index}

    val_desc.len := 0;                 {init all values to empty}
    val_val.len := 0;
    val_pack.len := 0;
    val_subs_set := false;
    val_subs := true;
    val_manu.len := 0;
    val_manun.len := 0;
    val_supp.len := 0;
    val_suppn.len := 0;
    for ii := 1 to maxorg do begin
      org[ii].numb.len := 0;
      end;
    nvals := 0;                        {init to no values saved this line}

    fieldn := 0;                       {init to before first field}
    while true do begin                {once for each field on this line}
      fieldn := fieldn + 1;            {make 1-N number of this field}
      string_token_comma (buf, p, tk, stat); {get this field string into TK}
      if string_eos(stat) then exit;   {done all fields on this line ?}
      if sys_error(stat) then goto done; {hard error ?}
      string_unpad (tk);               {remove trailing blanks}
      if tk.len <= 0 then next;        {nothing to do for empty fields}

      if fieldn = field_desc then begin
        string_copy (tk, val_desc);
        nvals := nvals + 1;
        end;

      if fieldn = field_val then begin
        string_copy (tk, val_val);
        nvals := nvals + 1;
        end;

      if fieldn = field_pack then begin
        string_copy (tk, val_pack);
        nvals := nvals + 1;
        end;

      if fieldn = field_subs then begin
        if tk.len > 0 then begin       {not blank ?}
          string_t_bool (tk, [string_tftype_yesno_k], val_subs, stat);
          if sys_error(stat) then goto err_atline;
          val_subs_set := true;
          nvals := nvals + 1;
          end;
        end;

      if fieldn = field_manu then begin
        string_copy (tk, val_manu);
        nvals := nvals + 1;
        end;

      if fieldn = field_manun then begin
        string_copy (tk, val_manun);
        nvals := nvals + 1;
        end;

      if fieldn = field_supp then begin
        string_copy (tk, val_supp);
        nvals := nvals + 1;
        end;

      if fieldn = field_suppn then begin
        string_copy (tk, val_suppn);
        nvals := nvals + 1;
        end;

      for ii := 1 to maxorg do begin   {once for each possible organization}
        if fieldn = org[ii].field then begin
          string_copy (tk, org[ii].numb);
          nvals := nvals + 1;
          end;
        end;
      end;                             {back for next field on this line}
    {
    *   All the relevant data from this line has been saved.
    }
    if nvals < 2 then next;            {must have 2 values for line to be useful}

    partref_part_new (list, part_p);   {make new reference part descriptor}

    string_copy (val_desc, part_p^.desc); {write simple fields into part descriptor}
    string_copy (val_val, part_p^.value);
    string_copy (val_pack, part_p^.package);
    part_p^.subst_set := val_subs_set;
    part_p^.subst := val_subs;

    if (val_manu.len > 0) and (val_manun.len > 0) then begin {have manuf and partnum ?}
      nameval_ent_new (part_p^.manuf, namval_p); {make new manuf list entry}
      nameval_set_name (part_p^.manuf, namval_p^, val_manu); {set manufacturer name}
      nameval_set_value (part_p^.manuf, namval_p^, val_manun); {set manuf part number}
      nameval_ent_add_end (part_p^.manuf, namval_p); {add this manuf/part to list}
      end;

    if (val_supp.len > 0) and (val_suppn.len > 0) then begin {have supplier and partnum ?}
      nameval_ent_new (part_p^.supplier, namval_p); {make new supplier list entry}
      nameval_set_name (part_p^.supplier, namval_p^, val_supp); {set supplier name}
      nameval_set_value (part_p^.supplier, namval_p^, val_suppn); {set supplier part number}
      nameval_ent_add_end (part_p^.supplier, namval_p); {add this supplier/part to list}
      end;

    for ii := 1 to maxorg do begin     {once for each possible org on this line}
      if org[ii].name.len <= 0 then next; {no organization name, skip it ?}
      if org[ii].numb.len <= 0 then next; {no part number, skip it ?}
      nameval_ent_new (part_p^.inhouse, namval_p); {add this org/partnum to the new part}
      nameval_set_name (part_p^.inhouse, namval_p^, org[ii].name);
      nameval_set_value (part_p^.inhouse, namval_p^, org[ii].numb);
      nameval_ent_add_end (part_p^.inhouse, namval_p);
      end;

    partref_part_add_end (list, part_p); {add the new part to the end of the list}
    end;                               {back to read next line from CSV file}
  goto done;                           {close the CSV file and leave}

err_atline:                            {error at current input file line}
(*
  writeln ('BUF = "', buf.str:buf.len, '"');
  writeln ('TK = "', tk.str:tk.len, '"');
*)
  sys_stat_set (string_subsys_k, string_stat_err_on_line_k, stat);
  sys_stat_parm_int (conn.lnum, stat);
  sys_stat_parm_vstr (conn.tnam, stat);

done:                                  {done reading input file}
  file_close (conn);
  end;
