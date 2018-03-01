let s:DEBUG = 'DEBUG'
let s:INFO = 'INFO'
let s:WARNING = 'WARNING'
let s:ERROR = 'ERROR'
let s:NOTSET = ''
let s:LEVELS = [
      \ s:DEBUG,
      \ s:INFO,
      \ s:WARNING,
      \ s:ERROR,
      \ s:NOTSET,
      \]
let s:output = ''
let s:format = '%{time} %{level}:%{module}:%{message}'
let s:date_format = '%Y-%m-%d'
let s:time_format = '%H-%M-%S'
let s:level = s:WARNING

function! s:_vital_loaded(V) abort
  let s:Path = a:V.import('System.Filepath')
endfunction

function! s:_vital_depends() abort
  return ['System.Filepath']
endfunction

function! s:_vital_created(module) abort
  let a:module.DEBUG = s:DEBUG
  let a:module.INFO = s:INFO
  let a:module.WARNING = s:WARNING
  let a:module.ERROR = s:ERROR
  let a:module.NOTSET = s:NOTSET
endfunction


" Public -------------------------------------------------------------------
function! s:get(script_file) abort
  let module = matchstr(
        \ a:script_file,
        \ '[\\/]autoload[\\/]\zs.*\ze\.vim$',
        \)
  let logger = {
        \ 'module': substitute(module, '[\\/]', '#', 'g'),
        \ 'debug': function('s:_logger_write', [s:DEBUG]),
        \ 'info': function('s:_logger_write', [s:INFO]),
        \ 'warning': function('s:_logger_write', [s:WARNING]),
        \ 'error': function('s:_logger_write', [s:ERROR]),
        \}
  lockvar logger
  return logger
endfunction

function! s:get_output() abort
  return s:output
endfunction

function! s:set_output(output) abort
  let s:output = fnamemodify(a:output, ':p')
endfunction

function! s:get_format() abort
  return s:format
endfunction

function! s:set_format(format) abort
  let s:format = a:format
endfunction

function! s:get_date_format() abort
  return s:date_format
endfunction

function! s:set_date_format(format) abort
  let s:date_format = a:format
endfunction

function! s:get_time_format() abort
  return s:time_format
endfunction

function! s:set_time_format(format) abort
  let s:time_format = a:format
endfunction

function! s:get_level() abort
  return s:level
endfunction

function! s:set_level(level) abort
  if index(s:LEVELS, a:level) == -1
    throw printf('vital: Logging: No such level %s exists', a:level)
  endif
  let s:level = a:level
endfunction


" Private ------------------------------------------------------------------
function! s:_emit(messages) abort
  if empty(s:output)
    return
  endif
  let parent = fnamemodify(s:output, ':h')
  if !isdirectory(parent)
    call mkdir(parent, 'p')
  endif
  call writefile(a:messages, s:output, 'a')
endfunction

function! s:_logger_write(level, message, ...) abort dict
  if index(s:LEVELS, s:level) > index(s:LEVELS, a:level)
    return
  endif
  let options = extend({
        \ 'throwpoint': 0,
        \}, a:0 ? a:1 : {},
        \)
  let messages = split(a:message, '\n')
  let m = s:format
  let m = substitute(m, '%{date}', strftime('%Y-%m-%d'), 'g')
  let m = substitute(m, '%{time}', strftime('%H:%M:%S'), 'g')
  let m = substitute(m, '%{level}', a:level, 'g')
  let m = substitute(m, '%{module}', self.module, 'g')
  let m = substitute(m, '%{message}', messages[0], 'g')
  if options.throwpoint
    call s:_emit([m] + messages[1:] + [v:throwpoint])
  else
    call s:_emit([m] + messages[1:])
  endif
endfunction
