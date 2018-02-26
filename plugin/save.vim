if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Functions {{{1
fu! save#buffer() "{{{2
    " When  we  save  a buffer,  the  marks  ]  and  [  do not  match  the  last
    " changed/yanked text but the whole buffer. We want to preserve these marks.
    let change_marks = [ getpos("'["), getpos("']") ]
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

" TODO:  In the  future, there may be a patch  improving `:lockmarks` to prevent
" the  change marks  from being  altered after  saving a  buffer.  Revisit  this
" function later if it's not needed anymore.

fu! save#toggle_auto(enable) abort "{{{2
    if a:enable && !exists('#auto_save_and_read')
        augroup auto_save_and_read
            au!
            " Save current buffer if it has been modified.
            " Why a timer?{{{
            "
            " Because we can't execute `:update` if we change the focused window
            " while  we're  on  the  command line  (E523).
            "
            " Maybe  because Vim  temporarily sets  'secure' when  we're on  the
            " command  line  and  the  system  is  busy  (because  we're  typing
            " characters and Vim  must process them or  react…).  This forbids
            " the execution of autocmds.
            "
            " But for some reason, using a timer allows us to execute `:update`,
            " even if  we're on the command  line.
            " Maybe because the timer delays the execution of the command until
            " the system is not busy anymore.
            "
            " MWE:
            "         :call timer_start(5000, {-> execute('let g:debug = 42', '')})
            "         :<c-r>=debug Enter
            "         … wait 5s on the command line
            "         :<c-r>=debug Enter
            "}}}
            "                                           ┌─ necessary to trigger autocmd sourcing vimrc
            "                                           │
            au BufLeave,CursorHold,WinLeave,FocusLost * nested call timer_start(0, {-> save#buffer()})
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

nno  <silent><unique>  <c-s>  :<c-u>call save#buffer()<cr>
nno  <silent><unique>  [oa    :<c-u>call save#toggle_auto(0)<cr>
nno  <silent><unique>  ]oa    :<c-u>call save#toggle_auto(1)<cr>
nno  <silent><unique>  coa    :<c-u>call save#toggle_auto(!exists('#auto_save_and_read'))<cr>
