
function! rmine#buffer#note#load()
  silent %delete _
  call s:buffer_setting()
  call s:append_expalin()
  call s:define_default_key_mappings()
  let &filetype = 'rmine_note'
  call rmine#util#clear_undo()
  call cursor(1,1)
  "startinsert!
endfunction

function! s:append_expalin()
  let msg = 'note : #' . b:rmine_cache.id . ' ' . b:rmine_cache.subject
  call append(0, msg)
  call append(1, rmine#util#ljust('', strwidth(msg), '-'))
  call append(2, [
        \ 'assigned_to : ' . (has_key(b:rmine_cache, 'assigned_to') ? b:rmine_cache.assigned_to.id . ' # ' . b:rmine_cache.assigned_to.name : ''),
        \ 'status      : ' . b:rmine_cache.status.id      . ' # ' . b:rmine_cache.status.name,
        \ 'tracker     : ' . b:rmine_cache.tracker.id     . ' # ' . b:rmine_cache.tracker.name ,
        \ 'priority    : ' . b:rmine_cache.priority.id    . ' # ' . b:rmine_cache.priority.name,
        \ 'start_date  : ' . (has_key(b:rmine_cache, 'start_date') ? b:rmine_cache.start_date : ''),
        \ 'due_date    : ' . (has_key(b:rmine_cache, 'due_date')   ? b:rmine_cache.due_date   : ''),
        \ 'done_ratio  : ' . (has_key(b:rmine_cache, 'done_ratio') ? b:rmine_cache.done_ratio : ''),
        \ 'hours       : ',
        \ 'activity    : ',
        \ ])

  if exists('b:rmine_cache.custom_fields') && type(b:rmine_cache.custom_fields) == v:t_list
    call s:append_custom_fields(b:rmine_cache.custom_fields, line('$') - 1)
  endif

  call append(line('$') - 1, '')
endfunction

function! s:append_custom_fields(fields, aline)
  let buflines = []
  let cf_def = rmine#util#custom_fields_cached(b:rmine_cache.project.id)
  if len(cf_def) > 0
    for field in a:fields
      if cf_def[field.id].field_format !~ 'attachment'
        let label = 'c_' . field.id . '_' . cf_def[field.id].field_format . '_' . field.name
        if has_key(cf_def[field.id], 'possible_values')
          let str = rmine#util#id_to_name(field.value, cf_def[field.id].possible_values)
          call add(buflines, label . ' |:| ' . str)
        else
          if cf_def[field.id].field_format == 'text'
            call add(buflines, label . ' |:| <<<')
            call extend(buflines, split(substitute(field.value, '\r\n\?', '\n', 'g'), '\n'))
            call add(buflines, label . ' |:| >>>')
          else
            call add(buflines, label . ' |:| ' . (type(field.value) == v:null ? '' : field.value))
          endif
        endif
      endif
    endfor
  else
    for field in a:fields
      let label = 'c_' . field.id . '_NOFMT_' . field.name
      call add(buflines, label . ' |:| ' . field.value)
    endfor
  endif
  call append(a:aline, buflines)
endfunction

function! s:buffer_setting()
  setlocal noswapfile
  setlocal buftype=acwrite
  setlocal nomodified
endfunction

function! s:post_note()
  let ret = input('post note ? (y/n) : ')
  if ret != 'y'
    redraw
    echohl Error | echo 'canceled' | echohl None
    return
  endif

  call cursor(3,1)
  
  " extract changed field
  let issue = {}
  let time_entry = {}
  let upload_files =[]
  while 1
    let line = getline('.')
    if line !~ '^#'
      if line =~ '^c_\d\+_\w\{-\}_.*|:|'
        " custom_field
        let matches = matchlist(line,  '^c_\zs\(\d\+\)\ze_\zs\(\w\{-\}\)\ze_.*|:|\zs\(.\+\)\ze$')
        if len(matches) > 3
          let modified = 0
          let updateval = ''
          let cid = matches[1]
          let cformat = matches[2]
          let cval = trim(matches[3])

          if cval == 'null'
            let updateval = cval
            let modified = 1
          else
            for item in b:rmine_cache.custom_fields
              if item.id == cid
                let multiple = exists('item.multiple') ? item.multiple : v:false
                if cformat =~ 'list\|bool\|enumeration\|version'
                  if exists('b:rmine_c_{cid}')
                    let updateval = multiple ? split(b:rmine_c_{cid}) : b:rmine_c_{cid}
                    let modified = 1
                  endif
                elseif cformat == 'text'
                  let updateval = []
                  while 1
                    execute "normal! \<Down>"
                    if line('.') == line('$')
                      break
                    endif
                    let line = getline('.')
                    let matches = matchlist(line,  '^c_\zs\(\d\+\)\ze_\zs\(\w\{-\}\)\ze_.*|:|\zs\(.\+\)\ze$')
                    if len(matches) > 3 && cid == matches[1]
                      break
                    else
                      call add(updateval, line)
                    endif
                  endwhile
                  let cval = join(updateval,  "\r\n")
                  if item.value != cval
                    let updateval = cval
                    let modified = 1
                  endif
                else
                  if item.value != cval
                    let updateval = cval
                    let modified = 1
                  endif
                endif
                break
              endif
            endfor
          endif
          if modified
            if !exists('issue.custom_fields')
              let issue.custom_fields = []
            endif
            call add(issue.custom_fields, {"id" : cid, "value" : updateval})
          endif
        endif
      else
        let pair = split(line, '\s\{0,}:\s\{0,}')
        if len(pair) > 1
          if pair[0] =~ '^upload_'
            let fpath = join(pair[1:], ':')
            let fname = matchstr(pair[0], '^upload_\zs')
            if fname == ''
              let fname = fnamemodify(fpath, ':t')
            endif
            call add(upload_files,
              \ {
              \   "filename": fname,
              \   "filepath": fpath,
              \   "mimetype": s:convert_mime_type(fpath),
              \ }
              \ )
          else
            let converted_key   = s:convert_key(pair[0])
            let converted_value = s:convert_value(converted_key, pair[1])
            if index(s:spent_fields, pair[0]) > -1
              let time_entry[converted_key] = converted_value
            else
              if !has_key(b:rmine_cache, pair[0])
                  let issue[converted_key] = converted_value
              else
                let target = type(b:rmine_cache[pair[0]]) == 4 ? b:rmine_cache[pair[0]].id : b:rmine_cache[pair[0]]
                if target != converted_value
                  let issue[converted_key] = converted_value
                endif
              endif
            endif
          endif
        elseif len(pair) > 0
          let converted_key   = s:convert_key(pair[0])
          if index(s:spent_fields, pair[0]) == -1
            if has_key(b:rmine_cache, pair[0])
              let target = type(b:rmine_cache[pair[0]]) == 4 ? b:rmine_cache[pair[0]].id : b:rmine_cache[pair[0]]
              if target != ''
                let issue[converted_key] = ''
              endif
            endif
          endif
        endif
      endif
    endif
    execute "normal! \<Down>"
    if line =~ '^$' || line('.') == line('$')
      break
    endif
  endwhile

  let issue.notes = join(getline('.', '$') , "\n")

  try
    for item in upload_files
      let ret = rmine#api#fileupload(item.filename, item.filepath)
      if !exists('issue.uploads')
        let issue.uploads = []
      endif
      call add(issue.uploads,
        \ {
        \   "token":        ret.upload.token,
        \   "filename":     item.filename,
        \   "content_type": item.mimetype
        \ })
    endfor

    let ret  = rmine#api#issue_update(b:rmine_cache.id, issue)
    if len(time_entry) > 0
      let ret = rmine#api#time_entry_activitie_update(b:rmine_cache.id, time_entry)
    endif
    bd!
    " moved to issue buffer
    call rmine#issue(b:rmine_cache.id)
    normal! G
    redraw!
  catch /^Error/
    echo v:exception
  finally
  endtry
endfunction

function! s:define_default_key_mappings()
  augroup rmine_note
    autocmd!
    nnoremap <buffer> <silent> q :bd!<CR>
    nnoremap <buffer> <silent> <CR> :call <SID>post_note()<CR>
    inoremap <buffer> <silent> <C-CR> <ESC>:call <SID>post_note()<CR>

    inoremap <silent> <buffer> <C-s> <ESC>:call unite#sources#rmine_selector#start()<CR>
    nnoremap <silent> <buffer> <C-s> <ESC>:call unite#sources#rmine_selector#start()<CR>
  augroup END

  if !exists('b:rmine_note_bufwrite_cmd')
    augroup rmine_note_bufwrite_cmd
      autocmd!
      autocmd BufWriteCmd <buffer> :call s:post_note()
      let b:rmine_note_bufwrite_cmd = 1
    augroup END
  endif
endfunction


" ↓ copy & paste

let s:convert_map = {
      \ 'project'     : 'project_id',
      \ 'assigned_to' : 'assigned_to_id',
      \ 'status'      : 'status_id',
      \ 'tracker'     : 'tracker_id',
      \ 'priority'    : 'priority_id',
      \ 'activity'    : 'activity_id',
      \ }

let s:spent_fields = [
      \ 'hours',
      \ 'activity',
      \ ]

let s:convert_mime = {
      \ 'png'     : 'image/png',
      \ 'jpg'     : 'image/jpg',
      \ 'jpeg'    : 'image/jpg',
      \ 'gif'     : 'image/gif',
      \ 'bmp'     : 'image/bmp',
      \ 'xls'     : 'application/vnd.ms-excel',
      \ 'xlsx'    : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      \ 'pdf'     : 'application/pdf',
      \ 'rtf'     : 'application/rtf',
      \ 'doc'     : 'application/msword',
      \ 'docx'    : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      \ 'ppt'     : 'application/vnd.ms-powerpoint',
      \ 'pptx'    : 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      \ 'zip'     : 'application/zip',
      \ 'tar'     : 'application/x-tar',
      \ 'txt'     : 'text/plain',
      \ }

function! s:convert_key(key)
  if has_key(s:convert_map, a:key)
    return s:convert_map[a:key]
  endif
  return a:key
endfunction

function! s:convert_mime_type(key)
  let ext = fnamemodify(a:key, ':e')
  if has_key(s:convert_mime, ext)
    return s:convert_mime[ext]
  endif
  return 'text/plain'
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
