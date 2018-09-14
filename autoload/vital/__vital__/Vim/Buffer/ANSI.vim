function! s:_vital_healthcheck() abort
  if (!has('nvim') && v:version >= 800) || has('nvim-0.2.0')
    return
  endif
  return 'This module requires Vim 8.0.0000 or Neovim 0.2.0'
endfunction

function! s:_vital_created(module) abort
  let s:COLORS = {
        \ '\%(30\|0;30\|30;0\)': 'AnsiColor0',
        \ '\%(31\|0;31\|31;0\)': 'AnsiColor1',
        \ '\%(32\|0;32\|32;0\)': 'AnsiColor2',
        \ '\%(33\|0;33\|33;0\)': 'AnsiColor3',
        \ '\%(34\|0;34\|34;0\)': 'AnsiColor4',
        \ '\%(35\|0;35\|35;0\)': 'AnsiColor5',
        \ '\%(36\|0;36\|36;0\)': 'AnsiColor6',
        \ '\%(37\|0;37\|37;0\)': 'AnsiColor7',
        \ '\%(1;30\|30;1\)': 'AnsiColor8',
        \ '\%(1;31\|31;1\)': 'AnsiColor9',
        \ '\%(1;32\|32;1\)': 'AnsiColor10',
        \ '\%(1;33\|33;1\)': 'AnsiColor11',
        \ '\%(1;34\|34;1\)': 'AnsiColor12',
        \ '\%(1;35\|35;1\)': 'AnsiColor13',
        \ '\%(1;36\|36;1\)': 'AnsiColor14',
        \ '\%(1;37\|37;1\)': 'AnsiColor15',
        \}
  call s:_define_highlight()
endfunction

function! s:_define_highlight() abort
  " Ref: https://github.com/w0ng/vim-hybrid
  highlight default AnsiColor0  ctermfg=0  guifg=#282A2E
  highlight default AnsiColor1  ctermfg=1  guifg=#A54242
  highlight default AnsiColor2  ctermfg=2  guifg=#8C9440
  highlight default AnsiColor3  ctermfg=3  guifg=#DE935F
  highlight default AnsiColor4  ctermfg=4  guifg=#5F819D
  highlight default AnsiColor5  ctermfg=5  guifg=#85678F
  highlight default AnsiColor6  ctermfg=6  guifg=#5E8D87
  highlight default AnsiColor7  ctermfg=7  guifg=#707880
  highlight default AnsiColor8  ctermfg=8  guifg=#373B41
  highlight default AnsiColor9  ctermfg=9  guifg=#CC6666
  highlight default AnsiColor10 ctermfg=10 guifg=#B5BD68
  highlight default AnsiColor11 ctermfg=11 guifg=#F0C674
  highlight default AnsiColor12 ctermfg=12 guifg=#81A2BE
  highlight default AnsiColor13 ctermfg=13 guifg=#B294BB
  highlight default AnsiColor14 ctermfg=14 guifg=#8ABEB7
  highlight default AnsiColor15 ctermfg=15 guifg=#C5C8C6
  augroup vital_vim_buffer_ansi
    autocmd! *
    autocmd ColorScheme * call s:_define_highlight()
  augroup END
endfunction

function! s:define_syntax(...) abort
  let prefix = get(a:000, 0, '')
  execute printf(
        \ 'syntax match %sAnsiSuppress conceal /\e\[[0-9A-Z;]*m/',
        \ prefix
        \)
  for [code, name] in items(s:COLORS)
    execute printf(
          \ 'syn region %s%s contains=%s keepend start=/\e\[%sm/ end=/\e\[[0-9A-Z;]*m/',
          \ prefix, name, 'AnsiSuppress', code
          \)
    execute printf(
          \ 'syntax cluster %sAnsiColors add=%s%s',
          \ prefix, prefix, name
          \)
  endfor
  setlocal conceallevel=3 concealcursor=nvic
endfunction
