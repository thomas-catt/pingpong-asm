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

const_controls_move_left_down:
    db 75

const_controls_move_left_up:
    db 203

const_controls_move_right_down:
    db 77

const_controls_move_right_up:
    db 205

const_controls_pause:
    db 1

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

const_players_ball_placement:
    db 40, 23
    db 40, 1

const_players_placement:
    db 30, 0
    db 30, 24

data_players_position:
    db 0, 0
    db 0, 0

data_ball_position:
    db 0, 0

data_ball_prev_position:
    db 40, 23

data_players_current:
    db 0

data_player_direction:
    db 0

data_ball_direction:
    db 1, -1

data_players_score:
    db 0
    db 0

data_game_paused:
    db 1

data_game_running:
    db 1

data_keyboard_key:
    db 0

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

code_game_check_ended:
    pusha
    
    
    
    popa
    ret

code_game_reset_positions:
    pusha
    
    mov si, const_players_placement
    mov di, data_players_position
    
    mov cx, 0
    add cl, [const_players_length]
    .for_each_player:
        mov ax, [si]
        mov [di], ax
        add si, 2
        add di, 2
        loop .for_each_player

    mov si, const_players_ball_placement
    mov ax, 0
    add al, [data_players_current]
    shl ax, 1
    add si, ax
    mov ax, [si]
    mov [data_ball_position], ax
    
    popa
    ret



code_players_display:
    pusha
    mov cx, 0
    add cl, [const_players_length]
    mov si, 0

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

; arguments:
; - ball position
code_players_ball_bounce:
    push bp
    mov bp, sp
    pusha
    
    mov bx, [bp + 4] ; ball position

    mov di, data_players_position
    mov ax, 0
    add al, [data_players_current]
    shl al, 1
    add di, ax
    mov ax, [di]

    inc byte [data_players_current]
    mov dh, [data_players_current]
    cmp dh, [const_players_length]
    jb .skip_player_length_loopover
    mov byte [data_players_current], 0
    .skip_player_length_loopover:

    
    cmp al, bl
    jl .ball_missed
    add al, [const_player_width]
    jge .ball_missed

    ; ball bounced
      
    jmp .end      
    .ball_missed:
    mov di, data_players_score
    mov ax, 0
    add al, [data_players_current]
    shl al, 1
    add di, ax
    inc byte [di]

    call code_game_check_ended
    call code_game_reset_positions
    
    .end:
    popa
    pop bp
    ret 2


code_players_loop:
    pusha
    
    mov di, data_players_position
    mov si, data_player_direction
    mov ax, 0
    add al, [data_players_current]
    shl al, 1
    add di, ax

    ; push [di]
    ; call code_util_print_number
    ; call code_util_endl

    mov ah, [cs:di]
    mov al, [cs:si]
    add ah, al
    mov [cs:di], ah

    popa
    ret


code_ball_display:
    pusha
    
    ; clean the old ball area
    push data_ball_prev_position
    call code_util_toPos
    mov ax, [const_chars_bg]
    mov [es:di], ax

    push data_ball_position
    call code_util_toPos
    mov ax, [const_chars_ball]
    mov [es:di], ax
    
    ; set previous position to current
    push word [data_ball_position]
    pop word [data_ball_prev_position]

    popa
    ret

code_ball_loop:
    pusha
    
    mov ax, [data_ball_position]
    mov bx, [data_ball_direction]
    add ah, bh
    add al, bl

    ; Check vertical boundary (ah is 0 or 25)
    cmp ah, 0
    je .flip_vertical
    cmp ah, 25
    je .flip_vertical
    jmp .check_horizontal

    .flip_vertical:
    neg byte bh    ; Flip vertical direction (1 <-> -1)
    mov di, [data_players_position]
    push ax
    call code_players_ball_bounce

    .check_horizontal:
    ; Check horizontal boundary (al is 0 or 80)
    cmp al, 0
    je .flip_horizontal
    cmp al, 80
    je .flip_horizontal
    jmp .continue_movement

    .flip_horizontal:
    neg byte bl    ; Flip horizontal direction (1 <-> -1)

    .continue_movement:

    mov [data_ball_position], ax
    mov [data_ball_direction], bx
    
    popa
    ret

code_keyboard_control:
    pusha

    mov si, data_player_direction
    ; mov ax, 0
    ; add al, [data_players_current]
    ; add si, ax

    mov al, [data_keyboard_key]
    cmp al, [const_controls_move_left_down]
    je .move_left_down

    cmp al, [const_controls_move_left_up]
    je .move_left_up

    cmp al, [const_controls_move_right_down]
    je .move_right_down

    cmp al, [const_controls_move_right_up]
    je .move_right_up

    cmp al, [const_controls_pause]
    je .pause

    jmp .end

    .move_left_down:
        mov byte [si], -1
        jmp .end
    
    .move_left_up:
    .move_right_up:
        mov byte [si], 0
        jmp .end
    
    .move_right_down:
        mov byte [si], 1
        jmp .end
    
    .pause:
        neg byte [data_game_paused]
        jmp .end
    
    .end:

    popa
    ret


code_isr_timer:
    mov ax, 0xb800
    mov es, ax

    mov ax, 0
    in al, 0x60
    cmp al, [data_keyboard_key]
    je .skip_keyboard_control
    mov [data_keyboard_key], al
    call code_keyboard_control
    .skip_keyboard_control:
    
    cmp byte [data_game_paused], 1
    jne .game_is_paused
    
    call code_players_loop
    call code_ball_loop

    call code_ball_display
    call code_players_display
    
    .game_is_paused:
    
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
    call code_game_reset_positions
    call code_hook_isr

code_inf:
    cmp byte [data_game_running], 1
    je code_inf

code_end:
    call code_unhook_isr
    mov ax, 0x3100
    int 0x21