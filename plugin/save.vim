if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Functions {{{1
fu save#buffer() "{{{2
    " Can't go back to old saved states with undotree mapping `}` if we save automatically.{{{
    "
    " If you  disable this `if`  block, when  you press `}`  to get back  to old
    " saved states,  you'll probably be  stuck in a  loop which includes  only 2
    " states, the last one and the last but one.
    "}}}
    if match(map(tabpagebuflist(), {_,v -> bufname(v)}), '^undotree_\d\+') >= 0
        return
    endif

    if &bt is# '' && bufname('%') isnot# ''
        " Why the bang after `:silent`?{{{
        "
        "     :sp /tmp/tex.tex
        "     :DebugLocalPlugin -kind ftplugin -filetype tex
        "     :e
        "     > f (finish sourcing the first script)
        "     G (move to the end of the pager)
        "
        " Focus another tmux window (!= pane), then come back:
        " `E523` is raised.
        "}}}
        sil! lockm update
    endif
endfu

fu s:enable_on_startup() abort "{{{2
    if !s:is_recovering_swapfile()
        " Does the autocmd which installed by `save#toggle_auto(1)` causes an issue?{{{
        "
        " It may.
        "
        " When you search for a pattern in a file, the matches are highlighted.
        " After 2s, 'hls' may, unexpectedly, be disabled by `vim-search`.
        " The  reason is  that Vim  has noticed  that the  search has  moved the
        " cursor, but too late.
        "
        " Solution1:
        " In ftplugin, set 'cole' to any value greater than `0`.
        "
        " Solution2:
        " In   ~/.vim/after/plugin/my_matchparen.vim,    install   any   autocmd
        " listening to `CursorMoved`:
        "
        "         au CursorMoved * "
        "
        " For an explanation of the issue, see:
        "
        "         https://github.com/vim/vim/issues/2053#issuecomment-327004968
        "}}}
        " Purpose of the variable:{{{
        "
        " Need to inspect it in `vim-statusline` to prevent the message `[no auto save]`
        " from being  included in the status  line when we've just  started Vim,
        " and the auto-saving autocmd has not been installed yet.
        "}}}
        let g:autosave_on_startup = 1
        sil call save#toggle_auto(1)
    endif
endfu

fu s:is_recovering_swapfile() abort "{{{2
    " https://stackoverflow.com/a/10358194/9780968
    sil return index(split(system('ps -o command= -p '.getpid())), '-r') >= 0
endfu

fu save#toggle_auto(enable) abort "{{{2
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
            " Could `nested` be useful here?{{{
            "
            " It could when  you modify your vimrc, and you  want the changes to
            " be sourced automatically.
            " More  generally,  it  could  be  useful  when  you  have  autocmds
            " listening to `BufWritePre` or `BufWritePost`.
            "}}}
            " Why don't you use `nested`?{{{
            "
            " I don't like the idea of the vimrc being re-sourced automatically.
            " I prefer having to press C-s.
            " Same thing for any command executed on `BufWritePre` or `BufWritePost`.
            "
            " Also, it may create spurious bugs.
            " For example, suppose you want to update a timestamp in a python buffer,
            " but only after having modified it and left it.
            " You could try this code:
            "
            "         augroup monitor_python_change
            "             au!
            "             au BufWritePre *.py call s:update_timestamp()
            "             au WinLeave * ++nested sil update
            "             "               ^
            "             "               ✘
            "         augroup END
            "
            "         fu s:update_timestamp() abort
            "             augroup update_timestamp
            "                 au!
            "                 au BufLeave * sil! 1/Last Modified: \zs.*/s//\=strftime('%c')/
            "                 \ | exe 'au! update_timestamp' | aug! update_timestamp
            "             augroup END
            "         endfu
            "
            " But it wouldn't work as expected:
            "
            "         $ vim -Nu /tmp/vimrc -O /tmp/py.py /tmp/vimrc
            "         :w (in the python buffer)
            "         C-w C-w (the time is updated in the python buffer ✔)
            "         C-w C-w (the time is updated in the vim buffer ✘)
            "}}}
            au BufLeave,CursorHold,WinLeave,FocusLost * call save#buffer()
        augroup END

    elseif !a:enable && exists('#auto_save_and_read')
        au! auto_save_and_read
        aug! auto_save_and_read
    endif
    " We have a flag in the tab line; we want it to be updated immediately.
    redrawt
endfu
" }}}1
" Mappings {{{1

nno <silent><unique> <c-s>   :<c-u>call save#buffer()<cr>
nno <silent><unique> [o<c-s> :<c-u>call save#toggle_auto(0)<cr>
nno <silent><unique> ]o<c-s> :<c-u>call save#toggle_auto(1)<cr>
nno <silent><unique> co<c-s> :<c-u>call save#toggle_auto(!exists('#auto_save_and_read'))<cr>
" }}}1

" Enable the automatic saving of a buffer.
" But not when we're trying to recover a swapfile.{{{
"
" When we're trying  to recover a swapfile, we don't  want the recovered version
" to automatically overwrite the original file.
"
" We prefer to save it in a temporary  file, and diff it against the original to
" check that the recovered version is indeed newer, and that no line is missing.
"}}}
unlet! s:did_shoot
au CmdlineEnter,CursorHold,InsertEnter * ++once
    \ if !get(s:, 'did_shoot', 0)
    \ |     let s:did_shoot = 1
    \ |     call s:enable_on_startup()
    \ | endif
" Why don't you call `save#toggle_auto(1)` directly?  Why using an autocmd?{{{
"
" Before calling `toggle_auto()`, we want to  make sure that Vim was not started
" to recover a swapfile (`-r` argument).
" To  check  this  we  call `s:is_recovering_swapfile()`;  this  function  calls
" `system()`; `system()` is too slow (≈ 20ms).
"}}}
