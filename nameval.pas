{   Routines that manipulate name/value pair lists.
*
*   The MEM_P field in the list control structure is used two different ways.
*   When the list is first initialized, it points to the parent memory context.
*   The first time dynamic memory is needed, a subordinate memory context is
*   created and MEM_P set pointing to it.  The field MEMCR is initialized to
*   FALSE to indicate the private memory context has not yet been created, and
*   is set to TRUE when it has been.
*
*   The above is done to make creating a list lightweight, with extra system
*   resources only allocated when the list is actually used.  Therefore, there
*   is little cost to creating many lists when only a small fraction of them
*   ever have any entries added to them.
}
module nameval;
define nameval_list_init;
define nameval_list_del;
define nameval_ent_new;
define nameval_ent_add_end;
define nameval_set_name;
define nameval_set_value;
define nameval_match;
define nameval_get_val;
%include 'stuff2.ins.pas';
{
********************************************************************************
*
*   Subroutine NAMEVAL_LIST_INIT (LIST, MEM)
*
*   Initialize a name/value list structure.  LIST is the structure to
*   initialize.  It is assumed that LIST has not previously been initialized and
*   no system state is allocated to it.
}
procedure nameval_list_init (          {initialize list of name/value pairs}
  out     list: nameval_list_t;        {the list to initialize}
  in out  mem: util_mem_context_t);    {parent memory context, will create subordinate}
  val_param;

begin
  list.mem_p := addr(mem);             {save pointer to parent memory context}
  list.first_p := nil;
  list.last_p := nil;
  list.nents := 0;
  list.memcr := false;                 {init to MEM_P pointing to parent context}
  end;
{
********************************************************************************
*
*   Subroutine NAMEVAL_LIST_DEL (LIST)
*
*   Delete any system resources allocated to the name/value list LIST.  The list
*   will become unusable, and must be initialized before being used again.
}
procedure nameval_list_del (           {delete (deallocate resources) of list}
  in out  list: nameval_list_t);       {the list to deallocate resources of}
  val_param;

begin
  if list.memcr
    then begin                         {private memory context was created}
      util_mem_context_del (list.mem_p); {deallocate the private memory context}
      end
    else begin                         {no private mem context was created}
      list.mem_p := nil;
      end
    ;
  list.first_p := nil;
  list.last_p := nil;
  list.nents := 0;
  list.memcr := false;
  end;
{
********************************************************************************
*
*   Subroutine NAMEVAL_ENT_NEW (LIST, ENT_P)
*
*   Create and initialize a new entry for a name/value list.  LIST is the list
*   that the new entry will be used with.  Entries can not be used across
*   different lists.  The entry will be created and initialized, but not added
*   to the list.
}
procedure nameval_ent_new (            {create and initialize new name/value list entry}
  in out  list: nameval_list_t;        {the list to create entry for}
  out     ent_p: nameval_ent_p_t);     {returned pointer to the new entry}
  val_param;

var
  mem_p: util_mem_context_p_t;         {pointer parent memory context}

begin
  if not list.memcr then begin         {not created private memory context yet ?}
    mem_p := list.mem_p;               {save pointer to parent memory context}
    util_mem_context_get (mem_p^, list.mem_p); {create our private memory context}
    list.memcr := true;                {indicate private context has been created}
    end;

  util_mem_grab (                      {create the new entry}
    sizeof(ent_p^), list.mem_p^, false, ent_p);

  ent_p^.prev_p := nil;                {initialize the fields}
  ent_p^.next_p := nil;
  ent_p^.name_p := nil;
  ent_p^.value_p := nil;
  end;
{
********************************************************************************
*
*   Subroutine NAMEVAL_ENT_ADD_END (LIST, ENT_P)
*
*   Add the entry pointed to by ENT_P to the end of the name/value list LIST.
*   The entry must have been created for this list.
*
*   The entry will be added to the end of the list.
}
procedure nameval_ent_add_end (        {add name/value entry to end of list}
  in out  list: nameval_list_t;        {the list to add the entry to}
  in      ent_p: nameval_ent_p_t);     {pointer to the entry to add}
  val_param;

begin
  ent_p^.prev_p := list.last_p;        {point back to previous entry}
  ent_p^.next_p := nil;                {no next entry, will be at end of chain}

  if list.last_p = nil
    then begin                         {this is first entry in list}
      list.first_p := ent_p;
      end
    else begin                         {adding to end of existing list}
      list.last_p^.next_p := ent_p;    {link last entry forwards to this one}
      end
    ;
  list.last_p := ent_p;                {update pointer to last entry in list}

  list.nents := list.nents + 1;        {count one more entry in the list}
  end;
{
********************************************************************************
*
*   Subroutine NAMEVAL_SET_NAME (LIST, ENT, NAME)
*
*   Set the name in the name/value list entry to the fixed string NAME.  The
*   list entry ENT must have been created for this list.
*
*   It is assumed that no previous name string is allocated.  A string of the
*   minimum required length will be allocated and filled in, then pointed to
*   from the entry.
}
procedure nameval_set_name (           {set name in name/value list entry}
  in      list: nameval_list_t;        {the list the entry is associated with}
  out     ent: nameval_ent_t;          {the entry to set the name of}
  in      name: univ string_var_arg_t); {the name to write into the entry}
  val_param;

begin
  string_alloc (name.len, list.mem_p^, false, ent.name_p); {allocate string mem}
  string_copy (name, ent.name_p^);     {copy the string}
  end;
{
********************************************************************************
*
*   Subroutine NAMEVAL_SET_VALUE (LIST, ENT, VALUE)
*
*   Set the value in the name/value list entry to the fixed string VALUE.  The
*   list entry ENT must have been created for this list.
*
*   It is assumed that no previous value string is allocated.  A string of the
*   minimum required length will be allocated and filled in, then pointed to
*   from the entry.
}
procedure nameval_set_value (          {set value in name/value list entry}
  in      list: nameval_list_t;        {the list the entry is associated with}
  out     ent: nameval_ent_t;          {the entry to set the value of}
  in      value: univ string_var_arg_t); {the value to write into the entry}
  val_param;

begin
  string_alloc (value.len, list.mem_p^, false, ent.value_p); {allocate string mem}
  string_copy (value, ent.value_p^);   {copy the string}
  end;
{
********************************************************************************
*
*   Function NAMEVAL_MATCH (LIST, NAME, VAL)
*
*   Determines whether NAME and VAL match a name/value pair in the list LIST.
*   The function returns one of these integer values:
*
*     -1  -  Positive mismatch.  NAME matched the name of one or more entries,
*            but VAL did not match the value of any of those.
*
*     0  -  No match.  No entry of name NAME was found, NAME was the empty
*           string, or VAL was the empty string.
*
*     1  -  Positive match.  A entry was found that matched both NAME and VAL.
}
function nameval_match (               {find whether name/value matches a list entry}
  in      list: nameval_list_t;        {the list to match against}
  in      name: univ string_var_arg_t; {the name to match}
  in      val: univ string_var_arg_t)  {the value to match}
  :sys_int_machine_t;                  {-1 = mismatch, 0 = no relevant entry, 1 = match}
  val_param;

var
  ent_p: nameval_ent_p_t;              {points to current list entry}

begin
  nameval_match := 0;                  {init to no matching entry found}
  if name.len <= 0 then return;        {no name to match against ?}
  if val.len <= 0 then return;         {no value to match against ?}

  ent_p := list.first_p;               {init to first list entry}
  while ent_p <> nil do begin          {loop over all the list entries}
    if string_equal(ent_p^.name_p^, name) then begin {NAME matches this entry ?}
      nameval_match := -1;             {found a matching entry, init to mismatch}
      if string_equal(ent_p^.value_p^, val) then begin {VAL also matches ?}
        nameval_match := 1;            {indicate positive match}
        return;
        end;
      end;
    ent_p := ent_p^.next_p;            {advance to next entry in the list}
    end;                               {back to check this new list entry}
  end;
{
********************************************************************************
*
*   Function NAMEVAL_GET_VAL (LIST, NAME, VAL)
*
*   Look up NAME in the name/value list LIST and return the value in VAL.  The
*   function returns TRUE iff a list entry with the indicated name was found.
*   When the function returns FALSE, VAL will be set to the empty string.
}
function nameval_get_val (             {look up name and get associated value}
  in      list: nameval_list_t;        {the list to look up in}
  in      name: univ string_var_arg_t; {the name to look up}
  in out  val: univ string_var_arg_t)  {returned value, empty string on not found}
  :boolean;                            {name was found}
  val_param;

var
  ent_p: nameval_ent_p_t;              {points to current list entry}

begin
  nameval_get_val := false;            {init to no matching entry found}
  val.len := 0;

  ent_p := list.first_p;               {init to first list entry}
  while ent_p <> nil do begin          {loop over all the list entries}
    if string_equal(ent_p^.name_p^, name) then begin {NAME matches this entry ?}
      string_copy (ent_p^.value_p^, val); {return the value string}
      nameval_get_val := true;         {indicate entry was found}
      return;
      end;
    ent_p := ent_p^.next_p;            {advance to next entry in the list}
    end;                               {back to check this new list entry}
  end;
