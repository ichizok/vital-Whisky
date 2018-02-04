let s:t_number = type(0)
let s:t_string = type('')
let s:pattern_short = '^-\w$'
let s:pattern_long = '^--[^ ]\+$'

function! s:parse(cmdline) abort
  let single_quote = '''\zs[^'']\+\ze'''
  let double_quote = '"\zs[^"]\+\ze"'
  let bare_strings = '\%(\\\s\|[^ ''"]\)\+'
  let parse_pattern = printf(
        \ '\%%(%s\)*\zs\%%(\s\+\|$\)\ze',
        \ join([single_quote, double_quote, bare_strings], '\|')
        \)
  return split(a:cmdline, parse_pattern)
endfunction

function! s:escape(str) abort
  return a:str =~# '\s' ? printf('''%s''', a:str) : a:str
endfunction

function! s:unescape(str) abort
  let s:strip_pattern = '^\%("\zs.*\ze"\|''\zs.*\ze''\|.*\)$'
  return matchstr(a:str, s:strip_pattern)
endfunction

function! s:search(args, options, ...) abort
  " Build rules and check if {args} includes one of them
  let rules = map(copy(a:options), { _, v -> s:_build_rule(v) })
  let pattern = join(map(copy(rules), { _, v -> v.pattern }), '\|')
  let index = call('match', [a:args, pattern] + a:000)
  if index == -1
    return {}
  endif
  " Scan rules to find a corresponding one
  let term = a:args[index]
  for rule in rules
    let m = matchlist(term, rule.pattern)
    if !empty(m)
      break
    endif
  endfor
  " Build info
  let option = get(rule, 'option', { v -> v })(m[2])
  let argument = get(
        \ map(copy(a:args), { _, v -> v =~# '^-' ? v:null : v }),
        \ index + 1,
        \ v:null,
        \)
  return {
        \ 'index': index,
        \ 'option': option,
        \ 'prefix': m[1],
        \ 'suffix': m[3],
        \ 'argument': argument,
        \}
endfunction

function! s:_build_rule(option) abort
  if len(a:option) == 2 && a:option =~# s:pattern_short
    " POSIX/GNU short option
    return {
          \ 'pattern': printf('^-\(\w\{-}\)\(%s\)\(.*\)$', a:option[1]),
          \ 'option': { v -> '-' . v },
          \}
  elseif len(a:option) > 2 && a:option =~# s:pattern_long
    " GNU long option
    return {
          \ 'pattern': printf('^\(\)\(%s\)\(=.*\)\?$', a:option),
          \}
  else
    " Unknown option
    return {
          \ 'pattern': printf('^\(\)\(%s\)\(\)$', a:option),
          \}
  endif
endfunction

function! s:pop(args, options, ...) abort
  let default = a:0 ? a:1 : v:null
  let info = call('s:search', [a:args, a:options] + a:000[1:])
  if empty(info)
    return default
  elseif info.option =~# s:pattern_short
    let value = s:_pop_short(a:args, info)
    return value is# v:null ? default : value
  else
    let value = s:_pop_long(a:args, info)
    return value is# v:null ? default : value
  endif
endfunction

function! s:_pop_short(args, info) abort
  if empty(a:info.prefix) && empty(a:info.suffix)
    if a:info.argument isnot# v:null
      call remove(a:args, a:info.index)
    endif
    call remove(a:args, a:info.index)
    return a:info.argument
  elseif !empty(a:info.prefix) && empty(a:info.suffix)
    let a:args[a:info.index] = substitute(a:args[a:info.index], a:info.option[1], '', '')
    if a:info.argument isnot# v:null
      call remove(a:args, a:info.index + 1)
    endif
    return a:info.argument
  else
    let a:args[a:info.index] = substitute(a:args[a:info.index], a:info.option[1], '', '')
    return v:null
  endif
endfunction

function! s:_pop_long(args, info) abort
  if empty(a:info.suffix)
    if a:info.argument isnot# v:null
      call remove(a:args, a:info.index)
    endif
    call remove(a:args, a:info.index)
    return a:info.argument
  els
    call remove(a:args, a:info.index)
    return matchstr(a:info.suffix, '^=\zs.*')
  endif
endfunction

function! s:set(args, options, ...) abort
  let value = a:0 ? a:1 : v:null
  let info = call('s:search', [a:args, a:options] + a:000[1:])
  if empty(info)
    if empty(value)
      return
    elseif value is# 1
      call insert(a:args, a:options[-1], 0)
    else
      call insert(a:args, s:escape(value), 0)
      call insert(a:args, a:options[-1], 0)
    endif
  elseif info.option =~# s:pattern_short
    return s:_set_short(a:args, info, value)
  else
    return s:_set_long(a:args, info, value)
  endif
endfunction

function! s:_set_short(args, info, value) abort
  if empty(a:value)
    call s:_pop_short(a:args, a:info)
  elseif a:value is# 1
    if empty(a:info.prefix) && empty(a:info.suffix)
      call s:_pop_short(a:args, a:info)
      call insert(a:args, a:info.option, a:info.index)
    elseif empty(a:info.suffix) && a:info.argument isnot# v:null
      call remove(a:args, a:info.index + 1)
    endif
  else
    if !empty(a:info.prefix) && empty(a:info.suffix) && a:info.argument isnot# v:null
      let a:args[a:info.index + 1] = s:escape(a:value)
    else
      call s:_pop_short(a:args, a:info)
      call insert(a:args, s:escape(a:value), a:info.index)
      call insert(a:args, a:info.option, a:info.index)
    endif
  endif
endfunction

function! s:_set_long(args, info, value) abort
endfunction
