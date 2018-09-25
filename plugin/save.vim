if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Functions {{{1
fu! save#buffer() "{{{2
    " When  we  save  a buffer,  the  marks  ]  and  [  do not  match  the  last
    " changed/yanked text but the whole buffer. We want to preserve these marks.
    let change_marks = [getpos("'["), getpos("']")]
    try
        if &bt is# '' && bufname('%') isnot# ''
            sil update
        endif
    catch
        return lg#catch_error()
    finally
        call setpos("'[", change_marks[0])
        call setpos("']", change_marks[1])
    endtry
endfu

" TODO:
" In the  future, there  may be  a patch improving  `:lockmarks` to  prevent the
" change marks from mutating after saving a buffer.  Revisit this function later
" if it's not needed anymore.

fu! save#toggle_auto(enable) abort "{{{2
    if a:enable && !exists('#auto_save_and_read')
        augroup auto_save_and_read
            au!
            " Save current buffer if it has been modified.
            " Warning: Do NOT delay `save#buffer()` with a timer.{{{
            "
            " Even if you have an issue for which delaying seems like a good fix.
            "
            " If you do use a timer, and:
            "
            "         1. the current buffer A is modified
            "         2. you press `]q` to move to the next entry in the qfl
            "         3. you end up in a new buffer B
            "
            " The buffer A won't be saved.
            "
            " But we could wrongly think that it has, and commit the old version
            " of A: this would make us lose all the changes we did in A.
            "}}}
            "                                           ┌ necessary to trigger autocmd sourcing vimrc
            "                                           │
            au BufLeave,CursorHold,WinLeave,FocusLost * nested call save#buffer()
            echo '[auto save] ON'
        augroup END

    elseif !a:enable && exists('#auto_save_and_read')
        au! auto_save_and_read
        aug! auto_save_and_read
        echo '[auto save] OFF'
    endif
endfu

sil call save#toggle_auto(1)

" NOTE:
" The autocmd which have just been installed causes an issue.
" When we search for a pattern in a file, the matches are highlighted.
" After 2s, 'hls' is, unexpectedly, disabled by `vim-search`.
" The reason is  Vim has noticed that  the search has moved the  cursor, but too
" late.
"
" Solution1:
" In ftplugin, set 'cole' to any value greater than `0`.
"
" Solution2:
" In ~/.vim/after/plugin/my_matchparen.vim, install any autocmd
" listening to `CursorMoved`:
"
"         au CursorMoved * "
"
" For an explanation of the issue, see:
"
"         https://github.com/vim/vim/issues/2053#issuecomment-327004968

" Mappings {{{1

nno  <silent><unique>  <c-s>    :<c-u>call save#buffer()<cr>
nno  <silent><unique>  [o<c-s>  :<c-u>call save#toggle_auto(0)<cr>
nno  <silent><unique>  ]o<c-s>  :<c-u>call save#toggle_auto(1)<cr>
nno  <silent><unique>  co<c-s>  :<c-u>call save#toggle_auto(!exists('#auto_save_and_read'))<cr>
