if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Autocmds {{{1

augroup hoist_nas | au!
    au User MyFlags call statusline#hoist('global',
        \ '%{!exists("#auto_save_and_read") ? "[NAS]" : ""}', 7, expand('<sfile>')..':'..expand('<sflnum>'))
augroup END

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
        sil! lockm update
    endif
endfu

fu s:enable_on_startup() abort "{{{2
    au! autosave_enable_on_startup
    aug! autosave_enable_on_startup
    if !s:is_recovering_swapfile()
        " for the next `#toggle_auto()` to work as expected, the augroup must not exist
        aug! auto_save_and_read
        " Does the autocmd installed by `save#toggle_auto(1)` cause an issue?{{{
        "
        " It may.
        "
        " When you search for a pattern in a file, the matches are highlighted.
        " After 2s, `'hls'` may – unexpectedly – be disabled by `vim-search`.
        " The  reason is  that Vim  has noticed  that the  search has  moved the
        " cursor, but too late.
        "
        " Solution1:
        " In a ftplugin, set `'cole'` to any value greater than `0`.
        "
        " Solution2:
        " In  `~/.vim/plugin/matchup.vim`,  install  any  autocmd  listening  to
        " `CursorMoved`:
        "
        "     au CursorMoved * "
        "
        " For an explanation of the issue, see:
        " https://github.com/vim/vim/issues/2053#issuecomment-327004968
        "}}}
        call save#toggle_auto(1)
    endif
endfu

fu s:is_recovering_swapfile() abort "{{{2
    " https://stackoverflow.com/a/10358194/9780968
    if has('nvim')
        sil return index(split(system('ps -o command= -p '..getpid())), '-r') >= 0
    else
        sil return index(v:argv, '-r') >= 0
    endif
endfu

fu save#toggle_auto(enable) abort "{{{2
    if a:enable && !exists('#auto_save_and_read')
        augroup auto_save_and_read | au!
            " Save current buffer if it has been modified.
            " Warning: Do NOT delay `save#buffer()` with a timer.{{{
            "
            " Even if you have an issue for which delaying seems like a good fix.
            "
            " If you do use a timer, and:
            "
            "    1. the current buffer A is modified
            "    2. you press `]q` to move to the next entry in the qfl
            "    3. you end up in a new buffer B
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
            " Why `++nested`?{{{
            "
            " It can help fix a bug in `vim-repeat`:
            "
            "     $ vim -Nu <(cat <<'EOF'
            "         sil e /tmp/file2 | %d | 0pu=['abcdef', 'abcdef']
            "         sil vs /tmp/file1 | %d | 0pu=['abcdef', 'abcdef']
            "         windo 1
            "         set ut=1000 | au CursorHold * update
            "         set rtp-=~/.vim
            "         set rtp-=~/.vim/after
            "         set rtp^=~/.vim/plugged/vim-repeat
            "         set rtp^=~/.vim/plugged/vim-sneak
            "     EOF
            "     )
            "     " press: dzcd j
            "     " wait for 'CursorHold' to be fired, and ':update' to be run
            "     " press: .
            "     " vim-sneak asks you for a pair of characters – again
            "     " it should not; it should automatically re-use the last one
            "
            " See: https://github.com/tpope/vim-repeat/issues/59#issuecomment-402012147
            "}}}
            au BufLeave,CursorHold,WinLeave,FocusLost * ++nested call save#buffer()
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
" TODO: Once Nvim supports `v:argv`:{{{
"
"    - remove this guard
"    - remove the `else` block
"    - remove `s:enable_on_startup()`
"    - simplify `s:is_recovering_swapfile()` (remove the `if` guard, and the block invoking `system()`)
"}}}
if !has('nvim')
    " But not when we're trying to recover a swapfile.{{{
    "
    " When  we're trying  to recover  a swapfile,  we don't  want the  recovered
    " version to automatically overwrite the original file.
    "
    " We prefer to save it in a temporary file, and diff it against the original
    " to check that the  recovered version is indeed newer, and  that no line is
    " missing.
    "}}}
    if !s:is_recovering_swapfile()
        call save#toggle_auto(1)
    endif
else
    " Why don't you call `save#toggle_auto(1)` directly?  Why using an autocmd?{{{
    "
    " Before calling  `#toggle_auto()`, we want  to make  sure that Vim  was not
    " started to recover a swapfile (`-r` argument).
    " To check  this we  call `s:is_recovering_swapfile()`; this  function calls
    " `system()`; `system()` is too slow (≈ 20ms).
    "}}}
    augroup autosave_enable_on_startup | au!
        au TextChanged,TextChangedI,CursorHold,CursorHoldI * call s:enable_on_startup()
    augroup END

    " when Nvim has just started, we don't want the flag `[NAS]` to be displayed in the tab line
    augroup auto_save_and_read
    augroup END
endif

