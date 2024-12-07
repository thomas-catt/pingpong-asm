[org 0x0100]
jmp code_start

;
;   D A T A - - - - - - - - - - - - - - - - - - - - 
;

const_strings_endl:
    db 0x0D, 0x0A, '$'

const_strings_hello:
    db "Hello world.$"
    
const_strings_single:
    db "?$"

const_chars_players:
    db ' ', 11110000b

const_chars_bg:
    dw 0x0720

const_chars_ball:
    db '*', 00000100b

const_player_width:
    db 20

const_players_length:
    db 2

const_players_names:
    db "A"
    db "B"

data_players_position:
    db 30, 0
    db 30, 24

data_ball_position:
    db 40, 23

data_players_direction:
    db 0
    db 0

data_ball_direction:
    db 1, -1

data_players_score:
    db 0
    db 0

data_game_running:
    db 1

data_isr_timer:
    dw 0, 0

   
;
;   C O D E - - - - - - - - - - - - - - - - - - - - 
;

code_util_clear:
    pusha
    
    mov ax, 0xb800
    mov es, ax
    mov di, 0
    mov cx, 2000
    mov ax, [const_chars_bg]
    rep stosw
    
    popa
    ret
 
; arguments:
; - position address
code_util_toPos:
    push bp
    mov bp, sp
    push 0 ; final position (bp - 2)
    pusha
    
    mov bx, [bp + 4] ; position address
    
    mov di, 0
    mov ah, [bx + 1] ; the y position
    mov al, [bx]     ; the x position

    mov cx, 0
    add cl, ah
    jz .skip_row_calc

    .for_each_row:
        add di, 80
        dec ah
        loop .for_each_row

    .skip_row_calc:

    add di, ax
    shl di, 1   ; multiply di by 2
    mov [bp - 2], di
    
    popa

    pop di ; saving value for di to return
    pop bp
    ret 2

; Arguments:
; - number to print
code_util_print_number:
    push bp
    mov bp, sp
    pusha

    ; Get number to print
    mov ax, [bp + 4]  ; number argument
    
    ; Convert number to digits
    mov cx, 0          ; digit counter
    mov di, sp         ; use stack to store digits

    ; Handle zero as a special case
    cmp ax, 0
    jne .convert_digits
    push '0'
    inc cx

    .convert_digits:
        ; Convert number to ASCII digits (least significant first)
        mov dx, 0          ; clear dx for division
        mov si, 10         ; divide by 10
        div si             ; ax = quotient, dx = remainder
        
        add dx, '0'        ; convert remainder to ASCII
        push dx            ; store digit on stack
        inc cx             ; increment digit count
        
        test ax, ax        ; check if quotient is zero
        jnz .convert_digits

    mov si, 0
    .print_digit:
        pop dx                          ; get next digit
        mov [const_strings_single], dl  ; move digit to al
        push const_strings_single
        call code_util_print
        inc si
        cmp si, cx                      ; check if all digits printed
        jl .print_digit

    popa
    pop bp
    ret 2


; arguments:
; - string to print
code_util_print:
    push bp
    mov bp, sp
    pusha

    mov dx, [bp + 4] ; string to print
    mov ah, 0x09
    int 0x21

    popa
    pop bp
    ret 2

code_util_endl:
    push const_strings_endl
    call code_util_print
    ret

code_players_display:
    pusha
    mov cx, 0
    add cl, [const_players_length]
    mov si, 0

    mov ax, 0xb800
    mov es, ax

    .for_each_player:
        mov bx, data_players_position
        add bx, si
        push bx
        call code_util_toPos

        ; padding before
        push di
        mov ax, [const_chars_bg]
        sub di, 2
        mov [es:di], ax
        pop di

        ; now di has the position to start the player rendering at
        push cx
        mov cx, 0
        add cl, [const_player_width]
        mov ax, [const_chars_players]

        .player_render_loop:
            mov [es:di], ax
            add di, 2
            loop .player_render_loop

        ; padding after
        mov ax, [const_chars_bg]
        mov [es:di], ax

        pop cx
        add si, 2
        loop .for_each_player
    
    popa
    ret


code_isr_timer:
    call code_players_display

    ; mov ax, 0
    ; in al, 0x60
    ; push ax
    ; call code_util_print_number
    
    add byte [data_players_position], 1
    sub byte [data_players_position + 2], 1
    
    jmp far [data_isr_timer]
    iret

code_hook_isr:
    pusha
    
    xor ax, ax
    mov es, ax
    

    mov ax, [es:8 * 4]
    mov [data_isr_timer], ax
    mov ax, [es:8 * 4 + 2]
    mov [data_isr_timer + 2], ax
    

    cli
    mov word [es:8 * 4], code_isr_timer
    mov word [es:8 * 4 + 2], cs
    sti
    
    popa
    ret


code_unhook_isr:
    pusha
    cli
    mov ax, [data_isr_timer]
    mov word [es:8 * 4], ax
    mov ax, [data_isr_timer + 2]
    mov word [es:8 * 4 + 2], ax
    sti
    popa
    ret

code_start:
    call code_util_clear
    call code_hook_isr

code_inf:
    cmp byte [data_game_running], 1
    je code_inf

code_end:
    call code_unhook_isr
    mov ax, 0x3100
    int 0x21