if exists('g:autoloaded_save')
    finish
endif
let g:autoloaded_save = 1

" Functions {{{1
fu! save#buffer() "{{{2
    if !&l:mod | return '' | endif

    let [ x_save, y_save ] = [ getpos("'x"), getpos("'y") ]
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
        call setpos("'x", x_save)
        call setpos("'y", y_save)
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
