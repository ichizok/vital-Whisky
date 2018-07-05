function! s:_vital_loaded(V) abort dict
  let s:operators = {}
  call extend(s:operators, a:V.import('Async.Observable.Operators.Concat'))
  call extend(s:operators, a:V.import('Async.Observable.Operators.Filter'))
  call extend(s:operators, a:V.import('Async.Observable.Operators.Flatmap'))
  call extend(s:operators, a:V.import('Async.Observable.Operators.Foreach'))
  call extend(s:operators, a:V.import('Async.Observable.Operators.Map'))
  call extend(s:operators, a:V.import('Async.Observable.Operators.Reduce'))
  call extend(s:operators, a:V.import('Async.Observable.Operators.Tap'))
endfunction

function! s:_vital_depends() abort
  return [
        \ 'Async.Observable.Operators.Concat',
        \ 'Async.Observable.Operators.Filter',
        \ 'Async.Observable.Operators.Flatmap',
        \ 'Async.Observable.Operators.Foreach',
        \ 'Async.Observable.Operators.Map',
        \ 'Async.Observable.Operators.Reduce',
        \ 'Async.Observable.Operators.Tap',
        \]
endfunction

function! s:concat(...) abort
  return call(s:operators.concat, a:000)
endfunction

function! s:filter(...) abort
  return call(s:operators.filter, a:000)
endfunction

function! s:flatmap(...) abort
  return call(s:operators.flatmap, a:000)
endfunction

function! s:foreach(...) abort
  return call(s:operators.foreach, a:000)
endfunction

function! s:map(...) abort
  return call(s:operators.map, a:000)
endfunction

function! s:reduce(...) abort
  return call(s:operators.reduce, a:000)
endfunction

function! s:tap(...) abort
  return call(s:operators.tap, a:000)
endfunction
