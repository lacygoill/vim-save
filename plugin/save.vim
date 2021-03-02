vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Options {{{1

# What does `'autoread'` do?{{{
#
# When  a file  is detected  to have  been changed  outside of  the current  Vim
# instance but not changed inside the latter, automatically read it again.
# Basically, it answers 'Yes', to the question where we usually answer `Load`.
#}}}
# When does Vim check whether a file has been changed outside the current instance?{{{
#
# In the terminal, when you:
#
#    - try to write the buffer
#    - execute a shell command
#    - execute `:checktime`
#
# Also when you give  the focus to a Vim instance where the  file is loaded; but
# only in  the GUI,  or in a  terminal which supports  the focus  event tracking
# feature, such as xterm (and if `'t_fd'` and `'t_fe'` are correctly set).
# See `:h xterm-focus-event`.
#}}}
set autoread

# Autocmds {{{1

augroup HoistNas | au!
    au User MyFlags statusline#hoist('global',
        \ '%{!exists("#AutoSaveAndRead") ? "[NAS]" : ""}', 7, expand('<sfile>:p') .. ':' .. expand('<sflnum>'))
augroup END

augroup MyChecktime | au!
    # Why `InsertEnter`?{{{
    #
    # The autocmd is adapted from blueyed's vimrc.
    #
    # I guess it makes sense because when  you're about to insert some text, you
    # want to be  sure you're editing the  most recent version of  the file, and
    # not an old one.  Editing an old one would cause a conflict when you'll try
    # to save the buffer.
    #}}}
    au BufEnter,CursorHold,InsertEnter * ++nested AutoChecktime()
augroup END

# Functions {{{1
def save#buffer() #{{{2
    # Can't go back to old saved states with undotree mapping `}` if we save automatically.{{{
    #
    # If you  disable this `if`  block, when  you press `}`  to get back  to old
    # saved states,  you'll probably be  stuck in a  loop which includes  only 2
    # states, the last one and the last but one.
    #}}}
    if tabpagebuflist()
     ->mapnew((_, v: number): string => bufname(v))
     ->match('^undotree_\d\+') >= 0
        return
    endif

    # Don't try to use `expand('<abuf>')`.
    # `:update` only works on the current buffer anyway.
    if &readonly
        || bufname('%') == ''
        || &buftype != ''
        return
    endif

    # Don't replace this `try/catch` with `sil!`.{{{
    #
    # `sil!` can lead to weird issues.
    #
    # For  example, once  we had  an issue  where a  regular buffer  was wrongly
    # transformed into a qf buffer: https://github.com/vim/vim/issues/7352
    #}}}
    try
        sil lockm update
    # Vim(update):E505: "/path/to/file/owned/by/root" is read-only (add ! to override)
    catch /^Vim\%((\a\+)\)\=:E505:/
        # let's ignore this error
    catch
        echohl ErrorMsg
        echom v:exception
        echohl NONE
    endtry
enddef

def IsRecoveringSwapfile(): bool #{{{2
    sil return index(v:argv, '-r') >= 0
enddef

def save#toggleAuto(enable = false) #{{{2
    if enable && !exists('#AutoSaveAndRead')
        augroup AutoSaveAndRead | au!
            # Save current buffer if it has been modified.
            # Warning: Do NOT delay `save#buffer()` with a timer.{{{
            #
            # Even if you have an issue for which delaying seems like a good fix.
            #
            # If you do use a timer, and:
            #
            #    1. the current buffer A is modified
            #    2. you press `]q` to move to the next entry in the qfl
            #    3. you end up in a new buffer B
            #
            # The buffer A won't be saved.
            #
            # But we could wrongly think that it has, and commit the old version
            # of A: this would make us lose all the changes we did in A.
            #}}}
            # Could `nested` be useful here?{{{
            #
            # It could when  you modify your vimrc, and you  want the changes to
            # be sourced automatically.
            # More  generally,  it  could  be  useful  when  you  have  autocmds
            # listening to `BufWritePre` or `BufWritePost`.
            #}}}
            # Why `++nested`?{{{
            #
            # It can help fix a bug in `vim-repeat`:
            #
            #     $ vim -Nu <(cat <<'EOF'
            #         sil e /tmp/file2 | %d | 0pu=['abcdef', 'abcdef']
            #         sil vs /tmp/file1 | %d | 0pu=['abcdef', 'abcdef']
            #         windo 1
            #         set ut=1000 | au CursorHold * update
            #         set rtp-=~/.vim
            #         set rtp-=~/.vim/after
            #         set rtp^=~/.vim/plugged/vim-repeat
            #         set rtp^=~/.vim/plugged/vim-sneak
            #     EOF
            #     )
            #     " press: dzcd j
            #     " wait for 'CursorHold' to be fired, and ':update' to be run
            #     " press: .
            #     " vim-sneak asks you for a pair of characters – again
            #     " it should not; it should automatically re-use the last one
            #
            # See: https://github.com/tpope/vim-repeat/issues/59#issuecomment-402012147
            #}}}
            au BufLeave,CursorHold,WinLeave,FocusLost * ++nested save#buffer()
        augroup END

    elseif !enable && exists('#AutoSaveAndRead')
        au! AutoSaveAndRead
        aug! AutoSaveAndRead
    endif
    # We have a flag in the tab line; we want it to be updated immediately.
    redrawt
enddef

def AutoChecktime() #{{{2
    var abuf: number = expand('<abuf>')->str2nr()
    if bufname(abuf) == ''
    || getbufvar(abuf, '&buftype', '') != ''
        return
    endif
    # What does it do?{{{
    #
    # Check whether  the current file has  been modified outside of  Vim.  If it
    # has, Vim will automatically re-read it because we've set 'autoread'.
    #
    # A modification  does not necessarily  involve the *contents* of  the file.
    # Changing its *permissions* is *also* a modification.
    #}}}
    #   Why `abuf`?{{{
    #
    # This function  will be  called frequently,  and if  we have  many buffers,
    # without specifiying a  buffer, Vim would check *all*  buffers.  This could
    # be too time-consuming.
    #}}}
    exe ':' .. abuf .. 'checktime'
enddef
# }}}1
# Mappings {{{1

nno <unique> <c-s> <cmd>call save#buffer()<cr>
nno <unique> [o<c-s> <cmd>call save#toggleAuto()<cr>
nno <unique> ]o<c-s> <cmd>call save#toggleAuto(v:true)<cr>
nno <unique> co<c-s> <cmd>call save#toggleAuto(!exists('#AutoSaveAndRead'))<cr>
# }}}1

# Enable the automatic saving of a buffer.
# But not when we're trying to recover a swapfile.{{{
#
# When  we're trying  to recover  a swapfile,  we don't  want the  recovered
# version to automatically overwrite the original file.
#
# We prefer to save it in a temporary file, and diff it against the original
# to check that the  recovered version is indeed newer, and  that no line is
# missing.
#}}}
if !IsRecoveringSwapfile()
    save#toggleAuto(true)
endif
