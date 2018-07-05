function! s:_vital_loaded(V) abort
  let s:Observable = a:V.import('Async.Observable')
endfunction

function! s:_vital_depends() abort
  return ['Async.Observable']
endfunction

function! s:map(fn) abort
  let ns = { 'fn': a:fn }
  return funcref('s:_map', [ns])
endfunction

function! s:_map(ns, source) abort
  return s:Observable.new({
        \ observer -> a:source.subscribe({
        \   'next': funcref('s:_map_next', [a:ns, observer]),
        \   'error': { e -> observer.error(e) },
        \   'complete': { -> observer.complete() },
        \ })
        \})
endfunction

function! s:_map_next(ns, observer, value) abort
  try
    let value = a:ns.fn(a:value)
  catch
    return a:observer.error({
          \ 'exception': v:exception,
          \ 'throwpoint': v:throwpoint,
          \})
  endtry
  call a:observer.next(value)
endfunction
