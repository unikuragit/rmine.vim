
if !exists('g:rmine_limits')
  let g:rmine_limits = 25
endif

" g:rmine_issue_includes :
"   fetch associated data (optional, use comma to fetch multiple associations).
"   Some possible values (for full list see below):
"     attachments - Since 3.4.0
"     relations
"     journals
"     children
let g:rmine_issue_includes = get(g:, 'rmine_issue_includes', 'journals')

let g:rmine_selector_items = get(g:, 'rmine_selector_items', {})

command! -nargs=? -complete=custom,rmine#complete#project Rmine :call rmine#issues_command(<f-args>)

command! -nargs=? -complete=custom,rmine#complete#project RmineAll :call rmine#issues_all(<f-args>)

command! -nargs=1 RmineIssue :call rmine#issue(<args>)

command! RmineNewIssue :call rmine#buffer#new_issue()
