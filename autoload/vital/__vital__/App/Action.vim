let s:t_list = type([])
let s:t_dict = type({})
let s:t_func = type(function('tr'))

let s:prefix = 'action'
let s:actions = {}
let s:aliases = {}

let s:MODIFIERS = [
      \ 'aboveleft',
      \ 'belowright',
      \ 'botright',
      \ 'browse',
      \ 'confirm',
      \ 'hide',
      \ 'keepalt',
      \ 'keepjumps',
      \ 'keepmarks',
      \ 'keeppatterns',
      \ 'lockmarks',
      \ 'noswapfile',
      \ 'silent',
      \ 'tab',
      \ 'topleft',
      \ 'verbose',
      \ 'vertical',
      \]

function! s:_vital_loaded(V) abort
  let s:Revelator = a:V.import('App.Revelator')
endfunction

function! s:_vital_depends() abort
  return ['App.Revelator']
endfunction

function! s:_vital_created(module) abort
  let a:module.name = 'action'
endfunction

function! s:get_prefix() abort
  return s:prefix
endfunction

function! s:set_prefix(prefix) abort
  let s:prefix = a:prefix
endfunction

function! s:register(name, callback, ...) abort
  let action = extend({
        \ 'name': a:name,
        \ 'callback': a:callback,
        \ 'description': '',
        \ 'options': {},
        \ 'hidden': 0,
        \ },
        \ a:0 ? a:1 : {},
        \)
  lockvar 3 action
  let s:actions[a:name] = action
endfunction

function! s:unregister(name) abort
  silent! unlet! s:actions[a:name]
endfunction

function! s:bind(...) abort
  let options = extend({
        \ 'candidates': function('s:_default_candidates'),
        \}, a:0 ? a:1 : {},
        \)
  let manager = {
        \ '_marked': [],
        \ '_candidates': options.candidates,
        \ '_available_actions': v:null,
        \ 'actions': function('s:_manager_actions'),
        \ 'aliases': function('s:_manager_aliases'),
        \ 'candidates': function('s_manager_candidates'),
        \ 'marked_candidates': function('s:_manager_marked_candidates'),
        \}
  let b:_vital_action_manager = manager
endfunction

function! s:actions() abort
  let manager = s:_get_manager()
  return s:_actions(manager)
endfunction

function! s:aliases() abort
  let manager = s:_get_manager()
  return s:_aliases(manager)
endfunction

function! s:candidates(...) abort range
  let s = exists('a:firstline') ? a:firstline : a:1
  let e = exists('a:lastline') ? a:lastline : a:2
  let manager = s:_get_manager()
  return s:_candidates(manager, s, e)
endfunction

function! s:marked_candidates(...) abort range
  let s = exists('a:firstline') ? a:firstline : a:1
  let e = exists('a:lastline') ? a:lastline : a:2
  let manager = s:_get_manager()
  return s:_marked_candidates(manager, s, e)
endfunction

function! s:call(expr, ...) abort range
  let s = exists('a:firstline') ? a:firstline : a:1
  let e = exists('a:lastline') ? a:lastline : a:2
  try
    let manager = s:_get_manager()
    let [action, mods] = s:_search_action(a:expr, manager)
    let candidates = action.use_marks
          \ ? s:_marked_candidates(manager, s, e)
          \ : s:_candidates(manager, s, e)
    let options = extend({
          \ 'mods': mods,
          \}, action.options,
          \)
    call action.callback(candidates, options)
  catch /vital: App\.Action:/
    echohl WarningMsg
    echo substitute(v:exception, 'vital: App\.Action:', '', '')
    echohl None
  endtry
endfunction

function! s:complete(arglead, cmdline, cursorpos) abort
  let terms = split(a:arglead, ' ', 1)
  " Build modifier candidates
  let modifiers = terms[:-2]
  let candidates = map(
        \ filter(copy(s:MODIFIERS), { _, v -> index(modifiers, v) == -1 }),
        \ { _, v -> v . ' ' },
        \)
  " Build action/alias candidates
  let arglead = terms[-1]
  let manager = s:_get_manager()
  let actions = s:_actions(manager)
  let aliases = s:_aliases(manager)
  if empty(arglead)
    call filter(actions, '!v:val.hidden')
  endif
  call extend(candidates, sort(keys(actions) + keys(aliases)))
  call filter(uniq(candidates), { _, v -> v =~# '^' . arglead })
  call map(candidates, { _, v -> join(modifiers + [v]) })
  return candidates
endfunction


function! s:_errormsg(message) abort
  return printf('vital: App.Action: %s', a:message)
endfunction

function! s:_get_manager() abort
  if !has_key(b:, '_vital_action_manager')
    throw s:_errormsg(printf(
          \ 'No action manager has defined on the buffer "%s"',
          \ bufname('%'),
          \))
  endif
  return b:_vital_action_manager
endfunction

function! s:_search_action(expr, manager) abort
  if empty(a:expr)
    throw s:_errormsg('An "expr" cannot be an empty string')
  endif
  let m = matchlist(a:expr, '^\(.\{-}\)\(\S\+\)$')
  let name = m[2]
  let mods = m[1]
  let actions = a:manager.actions()
  let aliases = a:manager.aliases()
  if has_key(aliases, name)
    return s:_search_action(mods . aliases[name], a:manager)
  elseif has_key(actions, name)
    return [actions[name], mods]
  endif
  " Find shortest match and use it
  let candidates = filter(
        \ keys(aliases) + keys(actions),
        \ { _, v -> v =~# '^' . name }
        \)
  if empty(candidates)
    throw s:_errormsg(printf(
          \ 'No action for "%s" is available on the buffer "%s"',
          \ name, bufname('%'),
          \))
  endif
  let name = sort(candidates, { a, b -> len(a) - len(b) })[0]
  return s:_search_action(mods . name, a:manager)
endfunction

function! s:_default_candidates(s, e) abort
  let candidates = getline(a:s, a:e)
  return map(
        \ candidates,
        \ { _, v -> { 'word': v } }
        \)
endfunction


" Manager ------------------------------------------------------------------
function! s:_actions(manager) abort
  if a:manager._available_actions is# v:null
    return copy(s:actions)
  endif
  return map(
        \ copy(a:manager._available_actions),
        \ { _, v -> s:actions[v] }
        \)
endfunction

function! s:_aliases(manager) abort
  let aliases = {}
  call extend(aliases, s:aliases)
  call extend(aliases, a:manager._aliases)
  return aliases
endfunction

function! s:_candidates(manager, s, e) abort
  if type(a:manager._candidates) == s:t_func
    return a:manager._candidates(a:s, a:e)
  else
    return a:manager._candidates[(a:s - 1) : (a:e - 1)]
  endif
endfunction

function! s:_marked_candidates(manager, s, e) abort
  if empty(a:manager._marked)
    return s:_candidates(a:manager, a:s, a:e)
  endif
  let candidates = []
  call map(
        \ copy(a:manager._marked),
        \ { _, v -> extend(candidates, s:_candidates(a:manager, v, v)) }
        \)
  return candidates
endfunction


" Action -------------------------------------------------------------------
function! s:_builtin_echo(candidates, options) abort
  for candidate in a:candidates
    echo string(candidate)
  endfor
endfunction
