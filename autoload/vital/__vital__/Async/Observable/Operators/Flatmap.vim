function! s:_vital_loaded(V) abort
  let s:Observable = a:V.import('Async.Observable')
endfunction

function! s:_vital_depends() abort
  return ['Async.Observable']
endfunction

function! s:flatmap(fn) abort
  let ns = { 'fn': a:fn, 'subscriptions': [] }
  return funcref('s:_flatmap', [ns])
endfunction

function! s:_flatmap(ns, source) abort
  return s:Observable.new(funcref('s:_flatmap_subscribe', [a:ns, a:source]))
endfunction

function! s:_flatmap_subscribe(ns, source, observer) abort
  let a:ns.outer = a:source.subscribe({
        \ 'next': funcref('s:_flatmap_next', [a:ns, a:observer]),
        \ 'error': { e -> a:observer.error(e) },
        \ 'complete': funcref('s:_flatmap_complete_if_done', [a:ns, a:observer]),
        \})
  return funcref('s:_flatmap_cleanup', [a:ns])
endfunction

function! s:_flatmap_next(ns, observer, value) abort
  if a:ns.fn isnot# v:null
    try
      let value = a:ns.fn(a:value)
    catch
      return a:observer.error({
            \ 'exception': v:exception,
            \ 'throwpoint': v:throwpoint,
            \})
    endtry
  else
    let value = a:value
  endif

  let a:ns.inner = s:Observable.from(value).subscribe({
        \ 'next': { v -> a:observer.next(v) },
        \ 'error': { e -> a:observer.error(e) },
        \ 'complete': funcref('s:_flatmap_complete_inner', [a:ns, a:observer]),
        \})

  call add(a:ns.subscriptions, a:ns.inner)
endfunction

function! s:_flatmap_complete_inner(ns, observer) abort
  let i = index(a:ns.subscriptions, a:ns.inner)
  if i isnot# -1
    call remove(a:ns.subscriptions, i)
  endif
  call s:_flatmap_complete_if_done(a:ns, a:observer)
endfunction

function! s:_flatmap_complete_if_done(ns, observer) abort
  if a:ns.outer.closed() && empty(a:ns.subscriptions)
    call a:observer.complete()
  endif
endfunction

function! s:_flatmap_cleanup(ns) abort
  call map(a:ns.subscriptions, { _, v -> v.unsubscribe() })
  call a:ns.outer.unsubscribe()
endfunction
