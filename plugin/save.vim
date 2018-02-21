if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Options {{{1

set autoread

" When a file has been detected to have been changed outside of Vim and
" it has not been changed inside of Vim, automatically read it again.
" Basically, it answers 'Yes', to the question where we usually answer `Load`.
"
" When the file has been deleted this is not done.
" If the buffer-local value is set, use this command to empty it and use
" the global value again:
"
"         :set autoread<

" Functions {{{1
fu! save#buffer() "{{{2
    " When  we  save  a buffer,  the  marks  ]  and  [  do not  match  the  last
    " changed/yanked text but the whole buffer. We want to preserve these marks.
    let change_marks = [ getpos("'["), getpos("']") ]
    try
        sil update
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
            "                                         ┌─ necessary to trigger autocmd sourcing vimrc
            "                                         │
            au BufLeave,CursorHold,WinLeave,FocusLost * nested if empty(&buftype)
                                                     \|     sil! call save#buffer()
                                                     \| endif
            echo '[auto save] ON'
        augroup END
    else
        sil! au! auto_save_and_read
        sil! aug! auto_save_and_read
        echo '[auto save] OFF'
    endif
endfu

sil call save#toggle_auto(1)

" NOTE:
" The 2 autocmds which have just been installed cause an issue.
" When we search for a pattern in a file, the matches are highlighted.
" After 2s, 'hls' is, unexpectedly, disabled by `vim-search`.
" The reason is  Vim has noticed that  the search has moved the  cursor, but too
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
"
"         https://github.com/vim/vim/issues/2053#issuecomment-327004968

" Mappings {{{1

nno  <silent><unique>  <c-s>  :<c-u>call save#buffer()<cr>
nno  <silent><unique>  [oa    :<c-u>call save#toggle_auto(0)<cr>
nno  <silent><unique>  ]oa    :<c-u>call save#toggle_auto(1)<cr>
nno  <silent><unique>  coa    :<c-u>call save#toggle_auto(!exists('#auto_save_and_read'))<cr>
