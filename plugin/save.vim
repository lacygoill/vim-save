if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Auto read {{{1

" When a file has been detected to have been changed outside of Vim and
" it has not been changed inside of Vim, automatically read it again.
" Basically, it answers 'Yes', to the question where we usually answer `Load`.
"
" When the file has been deleted this is not done.
" If the buffer-local value is set, use this command to empty it and use
" the global value again:
"
"         :set autoread<

set autoread

" Auto save {{{1 {{{1

sil call save#toggle_auto(1)

" Mappings {{{1

nno <silent> <c-s>  :<c-u>exe save#buffer()<cr>
nno <silent> [oa    :<c-u>exe save#toggle_auto(0)<cr>
nno <silent> ]oa    :<c-u>exe save#toggle_auto(1)<cr>
nno <silent> coa    :<c-u>exe save#toggle_auto(!exists('#auto_save_and_read'))<cr>

