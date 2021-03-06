
let s:convert_map = {
      \ 'project'     : 'project_id',
      \ 'assigned_to' : 'assigned_to_id',
      \ 'status'      : 'status_id',
      \ 'tracker'     : 'tracker_id',
      \ 'priority'    : 'priority_id',
      \ }

function! rmine#buffer#issue_new#load()
  silent %delete _
  call s:append_tempate()
  call s:buffer_setting()
  call s:define_default_key_mappings()
  setfiletype rmine_issue_new
  call cursor(1,1)
  startinsert!
endfunction

function! s:append_tempate()
  call append(0, [
        \ 'project     : ',
        \ 'subject     : ',
        \ 'assigned_to : ',
        \ 'status      : ',
        \ 'tracker     : ',
        \ 'priority    : ',
        \ 'start_date  : ',
        \ 'due_date    : ',
        \ 'done_ratio  : ',
        \ ''
        \ ])
endfunction

function! s:buffer_setting()
  setlocal noswapfile
  setlocal buftype=acwrite
  call rmine#util#clear_undo()
  setlocal nomodified
endfunction

function! s:define_default_key_mappings()
  augroup rmine_issue
    inoremap <silent> <buffer> <C-s> <ESC>:call unite#sources#rmine_selector#start()<CR>
    nnoremap <silent> <buffer> <C-s> <ESC>:call unite#sources#rmine_selector#start()<CR>

  augroup END

  if !exists('b:rmine_issue_new_bufwrite_cmd')
    augroup rmine_issue_new_bufwrite_cmd
      autocmd!
      autocmd BufWriteCmd <buffer> :call s:post_issue()
      let b:rmine_issue_new_bufwrite_cmd = 1
    augroup END
  endif
endfunction 

function! s:post_issue()
  call cursor(1,1)
  let issue = {}
  while 1
    let line = getline('.')
    let pair = split(line, '\s\{0,}:\s\{0,}')
    " changed field only
    if len(pair) > 1
      let converted_key = s:convert_key(pair[0])
      let issue[converted_key] = s:convert_value(converted_key, pair[1])
    endif
    execute "normal! \<Down>"
    if line =~ '^$' || line('.') == line('$')
      break
    endif
  endwhile
  
  for key in ['project_id', 'subject']
    if !s:check_blank(issue, key)
      echohl Error | echo key . ' is blank' | echohl None
      return
    endif
  endfor

  let project  = remove(issue, 'project_id')
  let subject  = remove(issue, 'subject')
  let desc     = join(getline('.', '$') , '') . ''

  let ret = input('post new issue ? (y/n) : ')
  if ret != 'y'
    redraw
    echohl Error | echo 'canceled' | echohl None
    return
  endif

  let res = rmine#api#issue_post(project, subject, desc, issue)
  bd!
  call rmine#issue(res.issue.id)
endfunction

function! s:check_blank(issue, key)
  if get(a:issue, a:key, '') == ''
    return 0
  endif
  return 1
endfunction

function! s:convert_key(key)
  if has_key(s:convert_map, a:key)
    return s:convert_map[a:key]
  endif
  return a:key
endfunction

function! s:convert_value(key, value)
  if a:key =~ 'id$'
    " trim to id only
    return substitute(a:value, ' .*', '', '')
  else
    " trim tail space
    return substitute(a:value, ' *$', '', '')
  endif
endfunction
