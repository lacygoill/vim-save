if exists('g:loaded_save')
    finish
endif
let g:loaded_save = 1

" Auto save {{{1 {{{1

sil call save#toggle_auto(1)


" Mappings {{{1

nno <silent> <c-s>  :<c-u>exe save#buffer()<cr>
nno <silent> [oa    :<c-u>exe save#toggle_auto(0)<cr>
nno <silent> ]oa    :<c-u>exe save#toggle_auto(1)<cr>
nno <silent> coa    :<c-u>exe save#toggle_auto(!exists('#auto_save_and_read'))<cr>

