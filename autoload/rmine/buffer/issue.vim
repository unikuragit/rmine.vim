" issue

function! rmine#buffer#issue#load(issue)
  call s:pre_process() 
  call s:load(a:issue)
endfunction

function! s:pre_process()
  setlocal noswapfile
  setlocal modifiable
  setlocal buftype=nofile
  call s:define_default_key_mappings()
  setfiletype rmine_issue
  silent %delete _
endfunction

function! s:load(issue)
  let b:rmine_cache = a:issue

  let header = s:create_header(a:issue)
  let custom_fields = s:create_custom_fields(a:issue)
  let desc   = s:create_description(a:issue)
  let notes  = s:create_notes(a:issue)

  call append(0, header + custom_fields + desc + ['', '', '<< comments >>', ''] + notes)
  delete _
  call rmine#util#clear_undo()
  :0
endfunction

function! s:create_custom_fields(issue)
  let issue = a:issue
  if !exists('issue.custom_fields') || type(issue.custom_fields) != v:t_list
    return []
  endif

  let title = '<<custom_fields>>'
  let fields = [
        \ title,
        \ ]
  let cf_def = rmine#util#custom_fields_cached(issue.project.id)
  for field in issue.custom_fields
    if has_key(cf_def, field.id)
      if has_key(cf_def[field.id], 'possible_values')
        let str = rmine#util#id_to_name(field.value, cf_def[field.id].possible_values)
        call add(fields, field.name . ' : ' . str)
      elseif cf_def[field.id].field_format == 'attachment'
        if field.value != ''
          let attachment = rmine#api#attachments(field.value)
        else
          let attachment = ''
        endif
        if type(attachment) == v:t_string
          call add(fields, field.name . ' : ' )
        else
          call add(fields, field.name . ' : '
              \ . attachment.content_url
              \ )
        endif
      elseif cf_def[field.id].field_format == 'text'
        call add(fields, field.name . ' : <<<')
        call extend(fields, split(substitute(field.value, '\r\n\?', '\n', 'g'), '\n'))
        call add(fields, '>>>')
      else
        call add(fields, field.name . ' : '
              \ . (type(field.value) == v:null ? '' : field.value)
              \ )
      endif
    else
      call add(fields, field.name . ' : '
            \ . (type(field.value) == v:null ? '' : field.value)
            \ )
    endif
  endfor
  return fields
endfunction

function! s:create_header(issue)
  let issue = a:issue
  let title = '[rmine] - ' . issue.project.name . '  #' . issue.id . ' ' . issue.subject
  let header = [
        \ title,
        \ '',
        \ 'author        : ' . issue.author.name,
        \ 'assigned_to   : ' . get(issue, 'assigned_to', {'name' : ''}).name,
        \ 'status        : ' . issue.status.name,
        \ 'tracker       : ' . issue.tracker.name,
        \ 'priority      : ' . issue.priority.name,
        \ 'category      : ' . get(issue, 'category'  , {'name' : ''}).name,
        \ 'fixed_version : ' . (exists('issue.fixed_version') ? issue.fixed_version.name : ''),
        \ 'start_date    : ' . get(issue, 'start_date', ''),
        \ 'due_date      : ' . get(issue, 'due_date'  , ''),
        \ 'done_ratio    : ' . issue.done_ratio,
        \ 'created_on    : ' . rmine#util#format_date(issue.created_on),
        \ 'updated_on    : ' . rmine#util#format_date(issue.updated_on),
        \ '',
        \ ]

  call extend(header, [
      \ 'estimated_hours : ' . string(get(issue, 'estimated_hours', '')) . ' (total:' . string(get(issue, 'total_estimated_hours', '')) . ')',
      \ 'spent_hours     : ' . string(get(issue, 'spent_hours', '')) . ' (total:' . string(get(issue, 'total_spent_hours', '')) . ')',
      \ '',
      \ ])

  let header_atch = []
  let attachments = get(issue, 'attachments', [])
  if len(attachments) > 0
    call add(header_atch, '<<attachments>>')
    for item in attachments
      let author = exists('item.author.name') ? item.author.name : ''
      let filename = exists('item.filename') ? item.filename : ''
      let size = exists('item.filesize') ? item.filesize : ''
      let create = exists('item.created_on') ? item.created_on : ''
      let url = exists('item.content_url') ? item.content_url : ''
      let detail = printf('%s(%s) : %s   %s(%s)', filename, size, url, author, create)
      call add(header_atch, detail)
    endfor
    call add(header_atch, '')
  endif

  let header_child = []
  let children = get(issue, 'children', [])
  if len(children) > 0
    call add(header_child, '<<children>>')
    for item in children
      call add(header_child, '#' . item.id . ':' . item.subject)
    endfor
    call add(header_child, '')
  endif

  let header_rel = []
  let relations = get(issue, 'relations', [])
  if len(relations) > 0
    call add(header_rel, '<<relations>>')
    for item in relations
      let rel_id = issue.id != item.issue_id ? item.issue_id : item.issue_to_id
      let rel_subject = rmine#api#simple_issue(rel_id).subject
      let rel_delay = exists('item.delay') && item.delay != v:null ? ':' . string(item.delay) : ''
      if item.issue_id == issue.id
        let text = ' (' . item.relation_type . rel_delay . ')>'
      else
        let text = '<(' . item.relation_type . rel_delay . ') '
      endif
      let text = printf('%-16S', text) . '#' . string(rel_id) . ':' . rel_subject
      call add(header_rel, text)
    endfor
    call add(header_rel, '')
  endif

  return extend(extend(extend(header, header_atch), header_child), header_rel)
endfunction

function! s:create_description(issue)
  let issue = a:issue
  let description = get(issue, 'description', '')
  let desc = []
  for line in split(description,"\n")
    let line = substitute(line , '' , '' , 'g')
    if line !~ "^h2\."
      let line = '  ' . line
    endif
    call add(desc , line)
  endfor

  return desc
endfunction

function! s:create_notes(issue)
  let issue = a:issue
  let notes = []
  for jnl in issue.journals
    "if !has_key(jnl, 'notes') || jnl.notes == ''
    "  continue
    "endif
    let name = jnl.user.name . ' - ' . jnl.created_on
    call add(notes, name)
    call add(notes, rmine#util#ljust('~', strwidth(name), '~'))
    for line in split(jnl.notes,"\n")
      call add(notes , '  ' . substitute(line , '' , '' , 'g'))
    endfor

    for dtl in jnl.details
      let detail = ''
      if exists('dtl.old_value')
        if exists('dtl.new_value')
          let detail = printf('  %s_%s : %s to %s', dtl.property, dtl.name, dtl.old_value, dtl.new_value)
        else
          let detail = printf('  %s_%s : Removed %s', dtl.property, dtl.name, dtl.old_value)
        endif
      else
        if exists('dtl.new_value')
          let detail = printf('  %s_%s : Added %s', dtl.property, dtl.name, dtl.new_value)
        endif
      endif
      if detail != ''
        call add(notes, detail)
      endif
    endfor

    call add(notes, '')
  endfor

  return notes
endfunction

function! s:open_relation_issue(opener)
  let opener = a:opener
  let no = matchstr(getline('.'), '#\zs\d\+')
  if no == ''
    return
  endif
  execute opener
  call rmine#issue(no)
endfunction

function! s:define_default_key_mappings()
  augroup rmine_issue
    nnoremap <silent> <buffer> <leader>r :call rmine#issue(b:rmine_cache.id)<CR>
    "nnoremap <silent> <buffer> <C-f> :call rmine#issue(b:rmine_cache.id - 1)<CR>
    "nnoremap <silent> <buffer> <C-b> :call rmine#issue(b:rmine_cache.id + 1)<CR>
    nnoremap <silent> <buffer> <Leader>s :call rmine#buffer#note()<CR>
    nnoremap <silent> <buffer> <Leader>b :call rmine#open_browser(b:rmine_cache.id)<CR>
    nnoremap <silent> <buffer> <CR> :call <SID>open_relation_issue('edit')<CR>
  augroup END
endfunction
