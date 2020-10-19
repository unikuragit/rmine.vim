let s:vital = vital#of('rmine.vim')
let s:http  = s:vital.import('Web.Http')

let s:cache = {}

function! rmine#api#versions(project_id)
  return s:get('projects/' . a:project_id . '/versions', {'limit' : g:rmine_limits}).versions
endfunction

function! rmine#api#projects(...)
  return s:get('projects', {'limit' : g:rmine_limits}).projects
endfunction

function! rmine#api#projects_all(...)
  let param = a:0 > 0 ? a:1 : {'limit' : g:rmine_limits}
  return s:get_all('projects', param, 'projects')
endfunction

function! rmine#api#project(id)
  return s:get('projects/' . a:id).project
endfunction
"
" project : all or project_id
"
function! rmine#api#issues(project, ...)
  let param = a:0 > 0 ? a:1 : {}
  let path  = a:project == 'all' ? 'issues' : 'projects/' . a:project . '/issues'
  let result = s:get(path, param)
  if a:project == 'all'
    return s:get(path, param).issues
  else
    return s:get_all(path, param, 'issues')
  endif
endfunction

function! rmine#api#issue(no)
  return s:get('issues/' . a:no, {'include' : g:rmine_issue_includes}).issue
endfunction
"{
"    "issue": {
"      "project_id": "example",
"      "subject": "Test issue",
"      "custom_field_values":{
"        "1":"1.1.3"  #the affected version field
"      }
"    }
"}
"
"{
"   'issue': {
"     'id'              : 67,
"     'status_id'       : 1
"     'author'          : {'id': 1, 'name': 'admin'},
"     'tracker_id'      : 4
"     'priority_id'     : 4
"     'project_id'      : 1
"     'done_ratio'      : 0,
"     'subject'         : 'あ',
"     'description'     : 'いいいいいいいいいいいいい',
"     'assigned_to_id'  : 1,
"     'start_date'      : '2012-11-23',
"     'due_date'        : '2012-11-24',
"     'estimated_hours' : 10,
"     'created_on'      : '2012-11-23T14:54:00Z',
"     'updated_on'      : '2012-11-23T14:54:00Z'
"     }
"   }
function! rmine#api#simple_issue(no)
  return s:get('issues/' . a:no).issue
endfunction

function! rmine#api#issue_post(project_id, subject, description, ...)
  let param = a:0 > 0 ? a:1 : {}
  let issue = {
        \ 'project_id'  : a:project_id,
        \ 'subject'     : a:subject,
        \ 'description' : a:description
        \ }
  let issue = extend(issue, param)
  return s:post('issues', {'issue' : issue})
endfunction

function! rmine#api#issue_update(no, param)
  return s:put('issues/' . a:no, {'issue' : a:param})
endfunction

function! rmine#api#fileupload(filename, filepath)
  return s:request_fileupload(a:filename, a:filepath)
endfunction

function! rmine#api#issue_delete(no)
  return s:delete('issues/' . a:no)
endfunction

function! rmine#api#issue_statuses()
  let statuses = get(s:cache, 'issue_statuses', [])
  if !empty(statuses)
    return copy(statuses)
  endif
  let statuses = s:get('issue_statuses', {'limit' : g:rmine_limits}).issue_statuses
  let s:cache['issue_statuses'] = statuses
  return statuses
endfunction

function! rmine#api#issue_priorities()
  return s:get('enumerations/issue_priorities', {'limit' : g:rmine_limits}).issue_priorities
endfunction

function! rmine#api#users()
  return s:get('users', {'limit' : g:rmine_limits}).users
endfunction

function! rmine#api#current_user()
  return s:get('users/current', {'limit' : g:rmine_limits}).user
endfunction

function! rmine#api#project_memberships(project_id)
  return s:get('projects/' . a:project_id . '/memberships', {'limit' : g:rmine_limits}).memberships
endfunction

function! rmine#api#trackers()
  return s:get('trackers', {'limit' : g:rmine_limits}).trackers
endfunction

function! rmine#api#queries()
  return s:get('queries', {'limit' : g:rmine_limits}).queries
endfunction

function! rmine#api#custom_fields()
  try
    return s:get('custom_fields').custom_fields
  catch /^Forbidden/
    echo 'Permission denied : custom_fields'
    return []
  endtry
endfunction

function! rmine#api#attachments(id)
  return s:get('attachments/' . a:id).attachment
endfunction

function! rmine#api#time_entry_activities()
  return s:get('enumerations/time_entry_activities', {'limit' : g:rmine_limits}).time_entry_activities
endfunction

function! rmine#api#time_entry_activitie_update(no, param)
  let param = a:param
  let param.issue_id = a:no
  return s:post('time_entries', {'time_entry' : param})
endfunction

"-------------- private -----------------

function! s:get(path, ...)
  return s:request('get', a:path, {}, a:0 > 0 ? a:1 : {})
endfunction

function! s:post(path, data, ...)
  return s:request('post', a:path, a:data, a:0 > 0 ? a:1 : {})
endfunction

function! s:put(path, data, ...)
  return s:request('put', a:path, a:data, a:0 > 0 ? a:1 : {})
endfunction

function! s:delete(path)
  return s:request('delete', a:path, {}, {})
endfunction

function! s:request(method, path, data, option)
  let path   = a:path =~ '^\/' ? a:path : '/' . a:path
  let option = a:option

  if exists('g:rmine_access_key')
    let option['key'] = g:rmine_access_key
  endif

  let url   = rmine#server_url() . path . '.json'
  let param = webapi#http#encodeURI(option)
  if strlen(param)
    let url .= "?" . param
  endif

  if a:method == 'GET'
    let ret = webapi#http#get(url)
  else
    let data = webapi#json#encode(a:data)
    let ret  = webapi#http#post(url, data, {'Content-Type' : 'application/json'} , toupper(a:method))
  endif

  if exists('ret.status')
    let status = ret.status
  else
    let status = substitute(ret.header[0], 'HTTP/1.\d ', '', '')
    let status = substitute(status, ' .*', '', '')
  endif
  if index(['200', '201', '204'], status) < 0
    if status =~ '^404' && exists('ret.error')
      return ret.error
    elseif status =~ '^403'
      throw ret.message . ' ' . ret.content
    elseif status =~ '^4'
      throw 'Error:' . ret.content
    else
      throw string(ret)
      "throw ret.header[0]
    endif
  endif

  " put or delete
  if ret.content =~ '^\s*$'
    return 1
  else
    return webapi#json#decode(ret.content)
  endif
endfunction

function! s:request_fileupload(filename, filepath)
  let cmd = printf('curl -s -X POST -H "Content-Type: application/octet-stream" -H "Expect:" -H "X-Redmine-API-Key: %s" -d @"%s" %s/uploads.json?filename=%s', g:rmine_access_key, a:filepath, rmine#server_url(), webapi#http#encodeURI(a:filename))
  let ret = eval(system(cmd))
  if exists('ret.errors')
    if type(ret.errors) == v:t_list
      throw join(ret.errors, "\n")
    elseif type(ret.errors) == v:t_dict
      throw string(ret.errors)
    else
      throw ret.errors
    endif
  elseif !exists('ret.upload.token')
    throw 'Invalid response ' . string(ret)
  endif
  return ret
endfunction

function! s:get_all(path, param, extendkey)
  let path = a:path
  let param = a:param
  let result = s:get(path, param)
  let exlist = deepcopy(result[a:extendkey])
  let cnt = len(exlist)
  let offset = 0
  let limit = result.limit
  let total_count = result.total_count
  while 1
    if total_count <= cnt | break | endif
    let param.offset = cnt
    let param.limit = limit
    let result = s:get(path, param)
    call extend(exlist, result[a:extendkey])
    let cnt = len(exlist)
  endwhile
  return exlist
endfunction

