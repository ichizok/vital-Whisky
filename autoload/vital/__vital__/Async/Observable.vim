let s:STATE_INITIALIZING = 0
let s:STATE_READY = 1
let s:STATE_RUNNING = 2
let s:STATE_BUFFERING = 3
let s:STATE_CLOSED = 4

function! s:_vital_healthcheck() abort
  if s:is_available()
    return
  endif
  return 'This module requires lambda and timers'
endfunction

function! s:_vital_loaded(V) abort
  let s:V = a:V
  let s:Promise = a:V.import('Async.Promise')
endfunction

function! s:_vital_depends() abort
  return ['Async.Promise']
endfunction

function! s:is_available() abort
  return has('lambda') && has('timers')
endfunction

function! s:is_observable(maybe_observable) abort
  return type(a:maybe_observable) is# v:t_dict
        \ && has_key(a:maybe_observable, '@@observable')
        \ && type(a:maybe_observable['@@observable']) is# v:t_func
endfunction

function! s:new(subscriber) abort
  return {
        \ '_subscriber': a:subscriber,
        \ '@@observable': funcref('s:_observable_observable'),
        \ 'subscribe': funcref('s:_observable_subscribe'),
        \ 'let': funcref('s:_observable_let'),
        \ 'pipe': funcref('s:_observable_pipe'),
        \ 'to_promise': funcref('s:_observable_to_promise'),
        \}
endfunction

function! s:of(...) abort
  return s:from(a:000)
endfunction

function! s:from(observable) abort
  if s:is_observable(a:observable)
    return a:observable['@@observable']()
  elseif type(a:observable) is# v:t_list
    return s:new({ observer ->
          \ s:_enqueue(funcref('s:_from_iterable', [a:observable, observer]))
          \})
  endif
  throw printf('vital: Async.Observable: %s is not observable', a:observable)
endfunction

function! s:_from_iterable(observable, observer) abort
  if a:observer.closed()
    return
  endif
  for item in a:observable
    call a:observer.next(item)
    if a:observer.closed()
      return
    endif
  endfor
  call a:observer.complete()
endfunction


" Observable ---------------------------------------------------------------
function! s:_observable_observable() abort dict
  return self
endfunction

function! s:_observable_subscribe(...) abort dict
  if a:0 is# 1 && type(a:1) is# v:t_dict
    let observer = a:1
  else
    let observer = {
          \ 'next': get(a:, 1, v:null),
          \ 'error': get(a:, 2, v:null),
          \ 'complete': get(a:, 3, v:null),
          \}
  endif
  return s:_subscription_new(observer, self._subscriber)
endfunction

function! s:_observable_let(operator) abort dict
  return call(a:operator, [self])
endfunction

function! s:_observable_pipe(...) abort dict
  let next = self
  for Operator in a:000
    let next = call(next.let, [Operator])
  endfor
  return next
endfunction

function! s:_observable_to_promise() abort dict
  return s:Promise.new(funcref('s:_observable_to_promise_resolver', [self]))
endfunction

function! s:_observable_to_promise_resolver(observable, resolve, reject) abort
  let ns = { 'value': v:null }
  call a:observable.subscribe({
        \ 'next': { v -> extend(ns, { 'value': v }) },
        \ 'error': { e -> a:reject(e) },
        \ 'complete': { -> a:resolve(ns.value) },
        \})
endfunction


" Subscription -------------------------------------------------------------
function! s:_subscription_new(observer, subscriber) abort
  let subscription = {
        \ '_cleanup': v:null,
        \ '_observer': a:observer,
        \ '_queue': v:null,
        \ '_state': s:STATE_INITIALIZING,
        \ 'closed': funcref('s:_subscription_closed'),
        \ 'unsubscribe': funcref('s:_subscription_unsubscribe'),
        \}
  let o = s:_subscription_observer_new(subscription)
  try
    let subscription._cleanup = a:subscriber(o)
  catch
    call o.error({
          \ 'exception': v:exception,
          \ 'throwpoint': v:throwpoint,
          \})
  endtry

  if subscription._state is# s:STATE_INITIALIZING
    let subscription._state = s:STATE_READY
  endif

  return subscription
endfunction

function! s:_subscription_closed() abort dict
  return self._state is# s:STATE_CLOSED
endfunction

function! s:_subscription_unsubscribe() abort dict
  if self._state isnot# s:STATE_CLOSED
    call s:_close_subscription(self)
    call s:_cleanup_subscription(self)
  endif
endfunction


" SubscriptionObserver -----------------------------------------------------
function! s:_subscription_observer_new(subscription) abort
  return {
        \ '_subscription': a:subscription,
        \ 'closed': funcref('s:_subscription_observer_closed'),
        \ 'next': funcref('s:_subscription_observer_next'),
        \ 'error': funcref('s:_subscription_observer_error'),
        \ 'complete': funcref('s:_subscription_observer_complete'),
        \}
endfunction

function! s:_subscription_observer_closed() abort dict
  return self._subscription._state is# s:STATE_CLOSED
endfunction

function! s:_subscription_observer_next(value) abort dict
  call s:_on_notify(self._subscription, 'next', a:value)
endfunction

function! s:_subscription_observer_error(error) abort dict
  call s:_on_notify(self._subscription, 'error', a:error)
endfunction

function! s:_subscription_observer_complete() abort dict
  call s:_on_notify(self._subscription, 'complete', v:null)
endfunction


" Private ------------------------------------------------------------------
function! s:_throw(exception) abort
  let exception = substitute(a:exception, '^Vim', '', '')
  throw exception
endfunction

function! s:_host_report_error(exception, throwpoint) abort
  try
    call themis#log(a:exception)
    call themis#log(a:throwpoint)
  catch
    call timer_start(0, { -> s:_throw(a:exception . "\n" . a:throwpoint) })
  endtry
endfunction

function! s:_enqueue(fn) abort
  " NOTE:
  " timer_start requires two times to keep correct queue order
  call timer_start(0, { -> timer_start(0, funcref('s:_enqueue_inner', [a:fn])) })
endfunction

function! s:_enqueue_inner(fn, ...) abort
  try
    call a:fn()
  catch
    call s:_host_report_error(v:exception, v:throwpoint)
  endtry
endfunction

function! s:_cleanup_subscription(subscription) abort
  let Cleanup = a:subscription._cleanup
  let a:subscription._cleanup = v:null

  if empty(Cleanup)
    return
  endif

  try
    if type(Cleanup) is# v:t_dict && has_key(Cleanup, 'unsubscribe')
      call Cleanup.unsubscribe()
    else
      call Cleanup()
    endif
  catch /Vim(call):E117/
  catch
    call s:_host_report_error(v:exception, v:throwpoint)
  endtry
endfunction

function! s:_close_subscription(subscription) abort
  let a:subscription._observer = v:null
  let a:subscription._queue = v:null
  let a:subscription._state = s:STATE_CLOSED
endfunction

function! s:_flush_subscription(subscription) abort
  let queue = a:subscription._queue
  if queue is# v:null
    return
  endif
  let a:subscription._queue = v:null
  let a:subscription._state = s:STATE_READY
  for [type, value] in queue
    call s:_notify_subscription(a:subscription, type, value)
    if a:subscription._state is# s:STATE_CLOSED
      return
    endif
  endfor
endfunction

function! s:_notify_subscription(subscription, type, value) abort
  let a:subscription._state = s:STATE_RUNNING

  let observer = a:subscription._observer
  try
    if a:type ==# 'next'
      if get(observer, 'next', v:null) isnot# v:null
        call observer.next(a:value)
      endif
    elseif a:type ==# 'error'
      call s:_close_subscription(a:subscription)
      if get(observer, 'error', v:null) isnot# v:null
        call observer.error(a:value)
      else
        call s:_throw(type(a:value) is# v:t_string ? a:value : string(a:value))
      endif
    elseif a:type ==# 'complete'
      call s:_close_subscription(a:subscription)
      if get(observer, 'complete', v:null) isnot# v:null
        call observer.complete()
      endif
    endif
  catch
    call s:_host_report_error(v:exception, v:throwpoint)
  endtry

  if a:subscription._state is# s:STATE_CLOSED
    call s:_cleanup_subscription(a:subscription)
  elseif a:subscription._state is# s:STATE_RUNNING
    let a:subscription._state = s:STATE_READY
  endif
endfunction

function! s:_on_notify(subscription, type, value) abort
  if a:subscription._state is# s:STATE_CLOSED
    return
  endif

  if a:subscription._state is# s:STATE_BUFFERING
    call add(a:subscription._queue, [a:type, a:value])
    return
  endif

  if a:subscription._state isnot# s:STATE_READY
    let a:subscription._state = s:STATE_BUFFERING
    let a:subscription._queue = [[a:type, a:value]]
    call s:_enqueue(funcref('s:_flush_subscription', [a:subscription]))
    return
  endif

  call s:_notify_subscription(a:subscription, a:type, a:value)
endfunction
