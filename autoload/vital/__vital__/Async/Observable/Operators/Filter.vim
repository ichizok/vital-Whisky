function! s:_vital_loaded(V) abort
  let s:Observable = a:V.import('Async.Observable')
endfunction

function! s:_vital_depends() abort
  return ['Async.Observable']
endfunction

function! s:filter(fn) abort
  let ns = { 'fn': a:fn }
  return funcref('s:_filter', [ns])
endfunction

function! s:_filter(ns, source) abort
  return s:Observable.new({
        \ observer -> a:source.subscribe({
        \   'next': funcref('s:_filter_next', [a:ns, observer]),
        \   'error': { e -> observer.error(e) },
        \   'complete': { -> observer.complete() },
        \ })
        \})
endfunction

function! s:_filter_next(ns, observer, value) abort
  try
    if !a:ns.fn(a:value)
      return
    endif
  catch
    return a:observer.error({
          \ 'exception': v:exception,
          \ 'throwpoint': v:throwpoint,
          \})
  endtry
  call a:observer.next(a:value)
endfunction
