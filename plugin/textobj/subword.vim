" Vim plugin for subword objects
" Maintainer: INAJIMA Daisuke <inajima@sopht.jp>
" Version: 0.1
" License: MIT License
"
" A subword consist of numbers and alphabetical characters.  All other
" characters are regarded as a delimiter.  A component of a CamelCase keyword
" is also subword.
"
" Keyword               Sub words
" -------------------------------------------
" VimTextobjSubword     Vim, Textobj, Subword
" vim_textobj__subword  vim, textobj, subword
" vim_textobjSubword    vim, textobj, Subword
"
" This object works like "aw" and "iw" in single word.

if exists('g:loaded_textobj_subword')
    finish
endif
let g:loaded_textobj_subword = 1

let s:save_cpo = &cpo
set cpo&vim

let s:subword_pattern =
\       '\v\C(\u[0-9A-Z]*[0-9a-z]*|([^0-9A-Za-z]|^)\zs[0-9a-z]+)'

call textobj#user#plugin('subword', {
\   '-': {
\       '*sfile*': expand('<sfile>:p'),
\       '*pattern*': s:subword_pattern,
\       '*select-a-function*': 's:select_a',
\       '*select-i-function*': 's:select_i',
\       'move-n': '',
\       'move-p': '',
\       'move-N': '',
\       'move-P': '',
\       'select-a': 'au',
\       'select-i': 'iu',
\   }
\})

function! s:select_a()
    return s:select(0)
endfunction

function! s:select_i()
    return s:select(1)
endfunction

function! s:getc(...)
    let off = (a:0 > 0) ? a:1 : 0
    return getline('.')[col('.') - 1 + off]
endfunction

function! s:_search_subword(flags, range)
    let col = searchpos(s:subword_pattern, a:flags, line('.'))[1]
    if col < a:range[0] || a:range[1] < col
        return 0
    endif
    return col
endfunction

function! s:_search_loop(c, func, args)
    let c = a:c
    let result = 0

    while c > 0
        let result = call(a:func, a:args)
        let c -= 1
    endwhile

    return result
endfunction

function! s:search_subword(flags, range, ...)
    let c = a:0 > 0 ? a:1 : 1

    return s:_search_loop(c, 's:_search_subword', [a:flags, a:range])
endfunction

function! s:select(inner)
    let c = v:count1

    " Ignore non-keywords
    if s:getc() !~# '\k'
        return 0
    endif

    let save_pos = getpos('.')
    let range = [searchpos('\<', 'bcn')[1], searchpos('.\>', 'cn')[1]]

    " Search start position and move cursor to tail of the first item
    if s:getc() =~# '[0-9A-Za-z]'
        call s:search_subword('bc', range)
        let start_pos = getpos('.')

        call s:search_subword('ce', range)
    else
        if s:search_subword('be', range)
            normal! l
        else
            call cursor(0, range[0])
        endif
        let start_pos = getpos('.')

        if s:search_subword('', range)
            normal! h
        else
            call cursor(0, range[1])
        endif
    endif

    if a:inner
        let c -= 1

        while c > 0
            if s:getc(1) !~# '\k'
                call setpos('.', save_pos)
                return 0
            elseif s:getc(1) =~# '[0-9A-Za-z]'
                if !s:search_subword('e', range)
                    call setpos('.', save_pos)
                    return 0
                endif
            else
                if s:search_subword('', range)
                    normal! h
                elseif c == 1
                    call cursor(0, range[1])
                    break
                else
                    call setpos('.', save_pos)
                    return 0
                endif
            endif
            let c -= 1
        endwhile

        let end_pos = getpos('.')
    else
        if s:getc() =~# '[0-9A-Za-z]'
            if c > 1 && !s:search_subword('e', range, c - 1)
                call setpos('.', save_pos)
                return 0
            endif

            let end_pos = getpos('.')

            if s:search_subword('', range)
                let end_pos = getpos('.')
                let end_pos[2] -= 1
            elseif end_pos[2] != range[1]
                let end_pos[2] = range[1]
            else
                call setpos('.', start_pos)
                if s:search_subword('be', range)
                    let start_pos = getpos('.')
                    let start_pos[2] += 1
                elseif start_pos[2] != range[0]
                    let start_pos[2] = range[0]
                endif
            endif
        else
            if !s:search_subword('e', range, c)
                call setpos('.', save_pos)
                return 0
            endif

            let end_pos = getpos('.')
        endif
    endif

    call setpos('.', save_pos)

    return ['v', start_pos, end_pos]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
