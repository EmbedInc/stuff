{   Program TEST_PARTREF [fnam]
*
*   Test the reference parts list manipulation routines.
}
program test_partref;
%include 'base.ins.pas';
%include 'stuff.ins.pas';

var
  fnam:                                {input file name}
    %include '(cog)lib/string_treename.ins.pas';
  parts: partref_list_t;               {the list of reference parts}
  part_p: partref_part_p_t;            {points to current part definition}
  namval_p: nameval_ent_p_t;           {points to current name/value list entry}
  partn: sys_int_machine_t;            {1-N number of current part}
  stat: sys_err_t;

begin
  string_cmline_init;                  {init for reading the command line}
  string_cmline_token (fnam, stat);    {read file name from command line}
  if string_eos(stat) then begin       {no command line argument ?}
    string_vstring (fnam, '(cog)progs/eagle/parts/parts.csv'(0), -1); {default}
    end;
  sys_error_abort (stat, '', '', nil, 0);
  string_cmline_end_abort;             {no other command line parameters allowed}

  partref_list_init (parts, util_top_mem_context); {init the parts list}
  partref_read_csv (parts, fnam, stat); {read CSV file data into the list}
  sys_error_abort (stat, '', '', nil, 0);

  writeln (parts.nparts, ' found');

  partn := 0;
  part_p := parts.first_p;             {init to first part in list}
  while part_p <> nil do begin         {once for each part in the list}
    partn := partn + 1;                {make 1-N number of this part}
    if partn > 1 then writeln;
    writeln ('Part ', partn);
    if part_p^.desc.len > 0 then begin
      writeln ('  Desc: ', part_p^.desc.str:part_p^.desc.len);
      end;
    if part_p^.value.len > 0 then begin
      writeln ('  Value: ', part_p^.value.str:part_p^.value.len);
      end;
    if part_p^.package.len > 0 then begin
      writeln ('  Package: ', part_p^.package.str:part_p^.package.len);
      end;
    if part_p^.subst_set then begin
      write ('  Subst: ');
      if part_p^.subst
        then writeln ('yes')
        else writeln ('no');
      end;
    namval_p := part_p^.inhouse.first_p;
    while namval_p <> nil do begin
      if (namval_p^.name_p <> nil) and (namval_p^.value_p <> nil) then begin
        writeln ('  Inhouse: ',
          namval_p^.name_p^.str:namval_p^.name_p^.len,
          ' ', namval_p^.value_p^.str:namval_p^.value_p^.len);
        end;
      namval_p := namval_p^.next_p;
      end;
    namval_p := part_p^.manuf.first_p;
    while namval_p <> nil do begin
      if (namval_p^.name_p <> nil) and (namval_p^.value_p <> nil) then begin
        writeln ('  Manuf: ',
          namval_p^.name_p^.str:namval_p^.name_p^.len,
          ' ', namval_p^.value_p^.str:namval_p^.value_p^.len);
        end;
      namval_p := namval_p^.next_p;
      end;
    namval_p := part_p^.supplier.first_p;
    while namval_p <> nil do begin
      if (namval_p^.name_p <> nil) and (namval_p^.value_p <> nil) then begin
        writeln ('  Supplier: ',
          namval_p^.name_p^.str:namval_p^.name_p^.len,
          ' ', namval_p^.value_p^.str:namval_p^.value_p^.len);
        end;
      namval_p := namval_p^.next_p;
      end;
    part_p := part_p^.next_p;
    end;
  end.
