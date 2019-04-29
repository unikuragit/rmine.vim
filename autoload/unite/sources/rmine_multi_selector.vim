
function! unite#sources#rmine_multi_selector#define()
  return s:source
endfunction

let s:source = {
      \ 'name': 'rmine/selector/multi',
      \ 'hooks' : {},
      \ 'action_table' : {},
      \ 'default_action' : {'common' : 'execute'},
      \ 'is_listed' : 0,
      \ }

let s:custom_field_selector_map = {
      \ 'list'        : 'custom_fields',
      \ 'bool'        : 'custom_fields',
      \ 'enumeration' : 'custom_fields',
      \ 'version'     : 'custom_fields',
      \ }

function! unite#sources#rmine_multi_selector#start(line, id, format)
  let line = a:line
  let id = a:id
  let format = a:format
  if !has_key(s:custom_field_selector_map, format)
    return
  endif
  try
    let lists = eval("rmine#api#" . s:custom_field_selector_map[format] . "()")
    for item in lists
      if item.id == id
        let multiple = exists('item.multiple') ? item.multiple : v:false
        if format == 'version'
          let versions = eval("rmine#api#versions(" . b:rmine_cache.project.id . ")")
          let list = versions
        else
          let list = item.possible_values
        endif
        break
      endif
    endfor
  catch
    echomsg v:exception
    echohl Error | echo 'not supported' | echohl None
    return
  endtry
  for v in list
    if format != 'version'
      let v.id       = v.value
      let v.name     = v.label
    else
    endif
    let v.selector = format
    let v.line     = line
    let v.custom_field = matchstr(line, '^c_\d\+')
    let v.multiple = multiple
  endfor
  return unite#start(['rmine/selector/multi'], {
        \ 'source__list'     : list,
        \ })
endfunction

function! s:source.gather_candidates(args, context)
  return map(a:context.source__list, '{
        \ "word"             : v:val.name,
        \ "id"               : v:val.id,
        \ "name"             : v:val.name,
        \ "selector"         : v:val.selector,
        \ "line"             : v:val.line,
        \ "custom_field"     : v:val.custom_field,
        \ "multiple"         : v:val.multiple,
        \ }')
endfunction

let s:source.action_table.execute = {'description' : 'select item', 'is_selectable' : 1}
function! s:source.action_table.execute.func(candidate)
  let cand = a:candidate
  let id = []
  let name = []
  let line = cand[0].line
  let multi = cand[0].multiple
  if !multi
    echo "Not selectable multiple"
    let id = cand[0].id
    let name = cand[0].name
  else
    for item in cand
      call add(id, item.id)
      call add(name, item.name)
    endfor
    let id = join(id, ' ')
    let name = join(name, ' ')
  endif
  execute 'let b:rmine_' . cand[0].custom_field . '=''' . id . ''''
  let line = substitute(line, '|:|.*', '', '') . '|:| ' . name
  call append('.', line)
  delete _
  execute "normal! \<Down>\<End>"
endfunction

function! unite#sources#rmine_multi_selector#id_sort(i1, i2)
  return a:i1.id - a:i2.id
endfunction


