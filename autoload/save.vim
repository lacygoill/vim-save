if exists('g:autoloaded_save')
    finish
endif
let g:autoloaded_save = 1

" Functions {{{1
fu! save#buffer() "{{{2
    if !&l:mod | return '' | endif

    let [ save_x, save_y ] = [ getpos("'x"), getpos("'y") ]
    let view = winsaveview()
    try
        try
            norm! `[mx`]my
        catch
        endtry

        try
            sil update
        catch
            return 'echoerr '.string(v:exception)
        endtry

        try
            norm! `xm[`ym]
        catch
        endtry

    finally
        call setpos("'x", save_x)
        call setpos("'y", save_y)
        call winrestview(view)
    endtry

    return ''
endfu

" When we save a buffer, the marks ]  and [ do not match the last changed/yanked
" text but the whole buffer. We want to preserve these marks.
"
" So, we:
"
"         • `[mx`]my    temporarily duplicate the marks (using marks x and y)
"         • update      save the buffer if needed
"         • `xm[`ym]    restore the marks
fu! save#toggle_auto(enable) abort "{{{2
    if a:enable
        augroup auto_save_and_read
            au!
            " When  no key  has been  pressed in  normal mode  for more  than 2s
            " ('updatetime'), check whether any buffer has been modified outside
            " of Vim.  If  one of them has been, Vim  will automatically re-read
            " the file because we've set 'autoread'.
            " NOTE:
            " A modification  does not necessarily  involve the contents  of the
            " file.  Changing its permissions is ALSO a modification.
            au CursorHold * sil! checktime

            " Also, save current buffer it if it has been modified.
            "
            "                                 ┌─ necessary to trigger autocmd sourcing vimrc
            "                                 │
            au BufLeave,CursorHold,WinLeave * nested if empty(&buftype)
                                                  \|     sil! exe save#buffer()
                                                  \| endif
            echo '[auto save] ON'
        augroup END
    else
        sil! au! auto_save_and_read
        sil! aug! auto_save_and_read
        echo '[auto save] OFF'
    endif
    return ''
endfu

" NOTE:
" These 2 autocmds cause an issue.
" When we search for a pattern in a file, the matches are highlighted.
" After 2s, 'hls' is, unexpectedly, disabled by `vim-search`.
" The reason  is Vim has noticed that  the search has moved the  cursor, but too
" late.
"
" Solution1:
" In ftplugin, set 'cole' to any value greater than `0`.
"
" Solution2:
" In ~/.vim/after/other_plugin/matchparen.vim, install any autocmd
" listening to `CursorMoved`:
"
"         au CursorMoved * "
"
" For an explanation of the issue, see:
"         https://github.com/vim/vim/issues/2053#issuecomment-327004968

