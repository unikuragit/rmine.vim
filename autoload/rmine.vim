

function! rmine#issues()
  let limit = 20
  let url   = s:server_url() . '/issues.json?limit=' . limit
  "let url   = s:server_url() . '/issues.json'
  if exists('g:unite_yarm_access_key')
    let url .= '&key=' . g:unite_yarm_access_key
  endif
  let res = webapi#http#get(url)
  " check status code
  if split(res.header[0])[1] != '200'
    call unite#yarm#error(res.header[0])
    return []
  endif
  " convert xml to dict
  let issues = webapi#json#decode(res.content).issues
  call rmine#buffer#load(issues)
  "for issue in webapi#json#decode(res.content).issues
  "endfor
  "return issues
  "return issues
endfunction
"
" get sever url
"
" http://yarm.org  → http://yarm.org
" http://yarm.org/ → http://yarm.org
"
function! s:server_url()
  return substitute(g:unite_yarm_server_url , '/$' , '' , '')
endfunction