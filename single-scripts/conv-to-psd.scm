 (define (conv-to-psd filename
          )
   (let* ((image (car (gimp-file-load RUN-NONINTERACTIVE filename filename)))
          (drawable (car (gimp-image-get-active-layer image))))
     ; (gimp-file-save RUN-NONINTERACTIVE image drawable filename filename)
     ; (file-psd-save 0 1 0 "test.psd" "test.psd" 0 0)
     (file-psd-save RUN-NONINTERACTIVE image drawable "test.psd" "test.psd" 0 0)
     (gimp-image-delete image)))

; gimp -i -b '(your-script-name "test.psd" 200 200)' -b '(gimp-quit 0)'
; gimp --verbose -i -b '(conv-to-psd "test.png")' -b '(gimp-quit 0)'

; must copy to ~/.gimp-2.6/scripts
; call with
;$ gimp --verbose -i -b '(conv-to-psd "/FULL/PATH/TO/myimg.png")' -b '(gimp-quit 0)'
