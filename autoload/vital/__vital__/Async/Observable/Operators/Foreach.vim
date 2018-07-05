function! s:_vital_loaded(V) abort
  let s:Promise = a:V.import('Async.Promise')
endfunction

function! s:_vital_depends() abort
  return ['Async.Promise']
endfunction

function! s:foreach(fn) abort
  let ns = { 'fn': a:fn }
  return { s -> s:Promise.new(funcref('s:_foreach', [ns, s])) }
endfunction

function! s:_foreach(ns, source, resolve, reject) abort
  let a:ns.resolve = a:resolve
  let a:ns.reject = a:reject
  let a:ns.subscription = a:source.subscribe({
        \ 'next': funcref('s:_foreach_next', [a:ns]),
        \ 'error': a:reject,
        \ 'complete': a:resolve,
        \})
endfunction

function! s:_foreach_next(ns, value) abort
  try
    call a:ns.fn(a:value, funcref('s:_foreach_done', [a:ns]))
  catch
    call a:ns.reject({
          \ 'exception': v:exception,
          \ 'throwpoint': v:throwpoint,
          \})
    call a:ns.subscription.unsubscribe()
  endtry
endfunction

function! s:_foreach_done(ns) abort
  call a:ns.subscription.unsubscribe()
  call a:ns.resolve()
endfunction
