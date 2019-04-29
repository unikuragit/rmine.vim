let s:Vital    = vital#of('rmine.vim')
let s:DateTime = s:Vital.import('DateTime')
let s:Html     = s:Vital.import('Web.Html')
let s:List     = s:Vital.import('Data.List')
"
"
"
function! rmine#util#format_date(date)
  return a:date
  let date_time = s:DateTime.from_format(a:date,'%Y-%m-%dT%H:%M:%SZ', 'C')
  return date_time.strftime("%Y/%m/%d %H:%M")
endfunction

function! rmine#util#ljust(msg, length, ...)
  let padstr = a:0 > 0 ? a:1 : ' '
  let msg = a:msg
  while strwidth(msg) < a:length
    let msg = msg . padstr
  endwhile
  return msg
endfunction


function! rmine#util#clear_undo()
  let old_undolevels = &undolevels
  setlocal undolevels=-1
  execute "normal a \<BS>\<Esc>"
  let &l:undolevels = old_undolevels
  unlet old_undolevels
endfunction

function! rmine#util#separator(s)
  let max = rmine#util#bufwidth()

  let sep = ""
  while len(sep) < max
    let sep .= a:s
  endwhile
  return sep
endfunction


function! rmine#util#bufwidth()
  let width = winwidth(0)
  if &l:number || &l:relativenumber
    let width = width - (&numberwidth + 1)
  endif
  return width
endfunction

function! rmine#util#custom_fields_cached(projectid)
  if !exists('s:rmine_custom_fields')
    let versions = rmine#api#versions(a:projectid)
    let cver = []
    let fields = rmine#api#custom_fields()
    if type(fields) == v:t_list
      for ver in versions
        let ver.value = string(ver.id)
        let ver.label = ver.name
        call add(cver, ver)
      endfor
      let todict = {}
      for field in fields
        if field.field_format == 'version'
          let field.possible_values = cver
        endif
        let todict[field.id] = field
      endfor
      let s:rmine_custom_fields = todict
    else
      let s:rmine_custom_fields = fields
    endif
  endif
  return s:rmine_custom_fields
endfunction

function! rmine#util#versions(id)
  if !exists('s:rmine_versions')
    let result = rmine#api#versions(a:id)
    if type(result) == v:t_list
      let todict = {}
      for field in result
        let todict[field.id] = field
      endfor
      let s:rmine_versions = todict
    else
      let s:rmine_versions = result
    endif
  endif
  return s:rmine_versions
endfunction

function! rmine#util#id_to_name(values, defs)
  let defs = a:defs
  let values = a:values
  let items = []
  for def in defs
    if type(values) == v:t_list
      if index(values, def.value) >= 0
        call add(items, def.label)
      endif
    else
      if values == def.value
        call add(items, def.label)
      endif
    endif
  endfor
  return join(items, ' ')
endfunction
