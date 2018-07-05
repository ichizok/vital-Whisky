function! s:_vital_loaded(V) abort
  let s:Observable = a:V.import('Async.Observable')
endfunction

function! s:_vital_depends() abort
  return ['Async.Observable']
endfunction

function! s:concat(...) abort
  let ns = {
        \ 'sources': copy(a:000),
        \ 'subscription': v:null,
        \}
  return funcref('s:_concat', [ns])
endfunction

function! s:_concat(ns, source) abort
  return s:Observable.new(funcref('s:_concat_subscribe', [a:ns, a:source]))
endfunction

function! s:_concat_subscribe(ns, source, observer) abort
  call s:_concat_start_next(a:ns, a:observer, a:source)
  return { -> s:_concat_cleanup(a:ns) }
endfunction

function! s:_concat_start_next(ns, observer, next) abort
  let a:ns.subscription = a:next.subscribe({
        \ 'next': { v -> a:observer.next(v) },
        \ 'error': { e -> a:observer.error(e) },
        \ 'complete': funcref('s:_concat_complete', [a:ns, a:observer]),
        \})
endfunction

function! s:_concat_complete(ns, observer) abort
  if empty(a:ns.sources)
    let a:ns.subscription = v:null
    call a:observer.complete()
  else
    call s:_concat_start_next(
          \ a:ns,
          \ a:observer,
          \ s:Observable.from(remove(a:ns.sources, 0)),
          \)
  endif
endfunction

function! s:_concat_cleanup(ns) abort
  if a:ns.subscription isnot# v:null
    call a:ns.subscription.unsubscribe()
    let a:ns.subscription = v:null
  endif
endfunction
