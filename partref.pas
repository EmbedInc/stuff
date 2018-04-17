{   Routines for manipulating lists of reference part definitions.
}
module partref;
define partref_list_init;
define partref_list_del;
define partref_part_new;
define partref_part_add_end;
%include 'stuff2.ins.pas';
{
********************************************************************************
*
*   Subroutine PARTREF_LIST_INIT (LIST, MEM)
*
*   Initialize the reference part definitions list LIST.  The list should not
*   have any resources allocated to it, since these won't be released.  LIST
*   should be either newly allocated memory, or have been deleted.
*
*   A new dynamic memory context will be created subordinate to MEM.  All
*   dynamic memory of the list will be allocated under the new context.
}
procedure partref_list_init (          {initialize list of reference part definitions}
  out     list: partref_list_t;        {the list to initialize}
  in out  mem: util_mem_context_t);    {parent memory context, will create subordinate}
  val_param;

begin
  util_mem_context_get (mem, list.mem_p); {create private mem context for the list}

  list.first_p := nil;                 {init the list fields}
  list.last_p := nil;
  list.nparts := 0;
  end;
{
********************************************************************************
*
*   Subroutine PARTREF_LIST_DEL (LIST)
*
*   Delete the reference part definitions list LIST.  All resources allocated to
*   the list will be deallocated.  The list can not be used until it is
*   initialized again.
}
procedure partref_list_del (           {deallocate resources of reference parts list}
  in out  list: partref_list_t);       {list to deallocate resources of, will be invalid}
  val_param;

begin
  util_mem_context_del (list.mem_p);   {deallocate all dynamic memory used by the list}

  list.first_p := nil;                 {reset list fields}
  list.last_p := nil;
  list.nparts := 0;
  end;
{
********************************************************************************
*
*   Subroutine PARTREF_PART_NEW (LIST, PART_P)
*
*   Create and initialize a new reference part definitions list entry.  LIST is
*   the list the entry will be part of.  Entries can not be used across lists.
*   PART_P will be returned pointing to the new list entry.  This entry will be
*   initialized, but will not be linked into the list.
}
procedure partref_part_new (           {create and initialize new partref list entry}
  in      list: partref_list_t;        {the list the entry will be part of}
  out     part_p: partref_part_p_t);   {returned pointer to the new entry, not linked}
  val_param;

begin
  util_mem_grab (                      {allocate memory for the new list entry}
    sizeof(part_p^), list.mem_p^, false, part_p);

  part_p^.prev_p := nil;               {initialize the fields}
  part_p^.next_p := nil;
  part_p^.desc.max := size_char(part_p^.desc.str);
  part_p^.desc.len := 0;
  part_p^.value.max := size_char(part_p^.value.str);
  part_p^.value.len := 0;
  part_p^.package.max := size_char(part_p^.package.str);
  part_p^.package.len := 0;
  part_p^.subst_set := false;
  part_p^.subst := true;
  nameval_list_init (part_p^.inhouse, list.mem_p^);
  nameval_list_init (part_p^.manuf, list.mem_p^);
  nameval_list_init (part_p^.supplier, list.mem_p^);
  end;
{
********************************************************************************
*
*   Subroutine PARTREF_PART_ADD_END (LIST, PART_P)
*
*   Add the part pointed to by PART_P to the end of the reference part
*   definitions list LIST.
}
procedure partref_part_add_end (       {add part to end of reference parts list}
  in out  list: partref_list_t;        {the list to add the part to}
  in      part_p: partref_part_p_t);   {poiner to the part to add}
  val_param;

begin
  part_p^.prev_p := list.last_p;       {set links in the entry}
  part_p^.next_p := nil;

  if list.last_p = nil
    then begin                         {the list is currently empty}
      list.first_p := part_p;
      end
    else begin                         {there are one or more previous entries}
      list.last_p^.next_p := part_p;
      end
    ;
  list.last_p := part_p;

  list.nparts := list.nparts + 1;      {count one more entry in the list}
  end;
