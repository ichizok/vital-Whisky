function! s:_vital_loaded(V) abort
  let s:Observable = a:V.import('Async.Observable')
endfunction

function! s:_vital_depends() abort
  return ['Async.Observable']
endfunction

function! s:reduce(fn, ...) abort
  let ns = {
        \ 'fn': a:fn,
        \ 'has_seed': a:0 isnot# 0,
        \ 'has_value': v:false,
        \ 'accumulate': a:0 ? a:1 : v:null,
        \}
  return funcref('s:_reduce', [ns])
endfunction

function! s:_reduce(ns, source) abort
  return s:Observable.new({
        \ observer -> a:source.subscribe({
        \   'next': funcref('s:_reduce_next', [a:ns, observer]),
        \   'error': { e -> observer.error(e) },
        \   'complete': funcref('s:_reduce_complete', [a:ns, observer]),
        \ })
        \})
endfunction

function! s:_reduce_next(ns, observer, value) abort
  let first = !a:ns.has_value
  let a:ns.has_value = v:true
  if !first || a:ns.has_seed
    try
      let a:ns.accumulate = a:ns.fn(a:ns.accumulate, a:value)
    catch
      return a:observer.error({
            \ 'exception': v:exception,
            \ 'throwpoint': v:throwpoint,
            \})
    endtry
  else
    let a:ns.accumulate = a:value
  endif
endfunction

function! s:_reduce_complete(ns, observer) abort
  if !a:ns.has_value && !a:ns.has_seed
    return a:observer.error(
          \ 'vital: Async.Observable.Operators.Reduce: Cannot reduce an empty sequence',
          \)
  endif
  call a:observer.next(a:ns.accumulate)
  call a:observer.complete()
endfunction
