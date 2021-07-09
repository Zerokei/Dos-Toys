
.386
data segment use16
buf db 0FFh; maxlen of buf
    db 0; init the len of buf
    db 0FFh dup(0); init the place to store input
op_item db 100h dup(0)
out_item dd 100h dup(0)
num dd 0; store current number
res dd 0; store the result
num1 dd 0
num2 dd 0
op dd 0; store the op
ten dd 0Ah; used as number 10
sixt dd 10h; used as number 16
two dd 02h; used as number 2
ibuf db 0; store current char
p_buf dw 0; 指向op_item的下标
p_op dw 0; 指向op_item的下标
p_out dw 0; 指向out_item的下标，同时在计算时表示p_out长度
p_i dw 0; 计算过程种，作为out_item的下标
sign1 dd 80000000h; use it to process op
sign2 dd 7FFFFFFFh; use it to retrieve op
mp  db '0'
    db '1'
    db '2'
    db '3'
    db '4'
    db '5'
    db '6'
    db '7'
    db '8'
    db '9'
    db 'A'
    db 'B'
    db 'C'
    db 'D'
    db 'E'
    db 'F'
data ends
code segment use16
assume cs:code, ds:data
main:
    mov ax, data
    mov ds, ax
    mov es, ax
    ;set the ds
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx
    ; init the register
read:
    mov ah, 0Ah
    mov dx, offset buf
    int 21h
    mov ah, 2
    mov dl, 0Dh
    int 21h
    mov ah, 2
    mov dl, 0Ah
    int 21h
    ; put the input into buf
reverse_polish_notation_init:
    mov p_buf, 2
reverse_polish_notation_loop:
    mov bx, p_buf
    cmp buf[bx], 0Dh
    je compute; buf[bh] == 0Dh
    mov al, buf[bx];
    mov ibuf,al 
    call deal_space
    
    ;p_buf++
    mov bx, p_buf
    inc bx
    mov p_buf, bx
    ;loop
    jmp reverse_polish_notation_loop
deal_space:
    cmp ibuf, ' '; compare with ' '
    jne deal_left_par
    ret
deal_left_par:
    cmp ibuf, '('; compare with '('
    jne deal_right_par
    mov bx, p_op
    mov al, ibuf
    mov op_item[bx], al; op_item[p_op] = buf[p_buf]
    inc bx
    mov p_op, bx
    ret
deal_right_par:
    cmp ibuf, ')'
    jne deal_digit
    call deal_right_par_loop
    mov p_op, bx
    ret
deal_right_par_loop:
    mov bx, p_op
    dec bx
    mov p_op, bx
    cmp op_item[bx], '('
    je deal_right_par_end
    
    mov eax, 0
    mov al, op_item[bx]
    or eax, sign1; eax = op_item[bx] | sign1
    
    mov bx, p_out
    mov out_item[bx], eax; store the op, and distinguish it from number(or sign1)
    add bx, 4h
    mov p_out, bx

    jmp deal_right_par_loop
deal_right_par_end:
    ret

;deal the digit
deal_digit:
    cmp ibuf, '0'
    jae deal_digit_1
    call deal_opers
    ret
deal_digit_1:
    cmp ibuf, '9'
    jbe deal_digit_2
    call deal_opers
    ret
deal_digit_2:;remain to fixed
    mov num, 0
    call deal_digit_loop

    mov eax, num

    mov bx, p_out
    mov out_item[bx], eax
    add bx, 4h
    mov p_out, bx
    
    ;p_buf = p_buf - 1
    mov bx, p_buf
    dec bx
    mov p_buf, bx

    ret; return to reverse_loop
deal_digit_loop:
    mov bx, p_buf
    mov al, buf[bx]
    mov ibuf ,al

    ;'0' <= ibuf <= '9'
    cmp ibuf, '0'
    jb deal_digit_end
    cmp ibuf, '9'
    ja deal_digit_end

    ;num = num * 10 + buf[bx] - '0'
    mov eax, num
    add num, eax
    shl eax, 3
    add num, eax
    mov eax, 0
    mov al, ibuf
    sub al, '0'
    add num, eax

    ; bx = bx - 1
    mov bx, p_buf
    inc bx
    mov p_buf, bx

    jmp deal_digit_loop
deal_digit_end:
    ret
;deal the opers
deal_opers:
    call deal_opers_loop
    ;op_item[p_op++] = ibuf
    mov bx, p_op
    mov al, ibuf
    mov op_item[bx], al
    inc bx
    mov p_op, bx
    ret
deal_opers_loop:
    mov bx, p_op
    cmp bx, 0
    je deal_opers_end
    cmp ibuf, '*'
    je deal_opers_mul_or_div
    cmp ibuf, '\'
    je deal_opers_mul_or_div
    cmp ibuf, '+'
    je deal_opers_add_or_del
    cmp ibuf, '-'
    je deal_opers_add_or_del
deal_opers_end:
    ret
deal_opers_mul_or_div:; if now we are in '+' or '-', and we meet '*' or '/'
    mov bx, p_op
    dec bx
    mov al, op_item[bx]
    cmp al, '*'
    je call_deal_opers_fun
    cmp al, '/'
    je call_deal_opers_fun
    ret; return to deal_opers
deal_opers_add_or_del:; if now we are in '+' or '-', and we meet '*' or '/' or '+' or '-'
    mov bx, p_op
    dec bx
    mov al, op_item[bx]
    cmp al, '('
    jne call_deal_opers_fun
    ret; return to deal_opers
call_deal_opers_fun:
    call deal_opers_fun
    jmp deal_opers_loop; jump to the deal_op_loop
deal_opers_fun:;out_item[p_out++] = op_item[--p_op]|sign1
    mov bx, p_op
    dec bx
    mov p_op, bx

    mov eax, 0
    mov al, op_item[bx]
    or eax, sign1

    mov bx, p_out
    mov out_item[bx], eax
    
    add bx, 4
    mov p_out, bx
    ret

deal_rest:
    mov bx, p_op
    cmp bx, 0
    je deal_rest_end
    
    call deal_opers_fun;out_item[p_out++] = op_item[--p_op]|sign1
    loop deal_rest

deal_rest_end:
    ret
;compute part
compute:
    call deal_rest
    mov p_i, 0
compute_loop:
    cmp p_out, 4h
    jbe output
    mov bx, p_i
    call find_op_loop
    mov p_i, bx
    ; op = out_item[bx], num1 = out_item[bx - 1], num2 = out_item[bx - 2]
    mov eax, out_item[bx]
    and eax, sign2
    mov op, eax
    sub bx, 4h
    mov eax, out_item[bx]
    mov num2, eax
    sub bx, 4h
    mov eax, out_item[bx]
    mov num1, eax

    cmp op, '+'
    je fun_add
    cmp op, '-'
    je fun_sub
    cmp op, '*'
    je fun_mul
    cmp op, '/'
    je fun_div
compute_loop_res:
    ;the result is stored in eax
    mov out_item[bx], eax
    
    ;memcpy
    mov cx, p_out
    sub cx, p_i
    sub cx, 4h; move length = cx = p_out - p_i - 1(8)

    ;set the address
    
    mov si, offset out_item
    add si, p_i
    mov di, si
    add si, 4h; si = p_i+1
    sub di, 4h; di = p_i-1
    cld; DF = 0
    rep movsd

    add bx, 4h
    mov p_i, bx

    ;bx = bx - 2
    mov bx, p_out
    sub bx, 4h
    sub bx, 4h
    mov p_out, bx
    jmp compute_loop

find_op_loop:
    mov eax, out_item[bx]
    and eax, sign1
    jnz find_op_end
    add bx, 4h
    jmp find_op_loop
find_op_end:
    ret

fun_add:
    mov eax, num1
    add eax, num2
    jmp compute_loop_res
fun_sub:
    mov eax, num1
    sub eax, num2
    jmp compute_loop_res
fun_mul:
    mov edx, 0
    mov eax, num1
    mul num2
    jmp compute_loop_res
fun_div:
    mov edx, 0
    mov eax, num1
    div num2
    jmp compute_loop_res
;output part
output:
    ; output with Decimal type
    mov bx, 0
    mov eax, out_item[bx]
    mov res, eax
    mov cx, 0; the numbers have been put
    call output_10

    ;wrap
    mov ah, 2
    mov dl, 0Dh
    int 21h
    mov ah, 2
    mov dl, 0Ah
    int 21h

    ; output with Hexadecimal type
    mov bx, 0
    mov eax, out_item[bx]
    mov res, eax
    mov cx, 0; the numbers have been put
    call output_16

    ;wrap
    mov ah, 2
    mov dl, 0Dh
    int 21h
    mov ah, 2
    mov dl, 0Ah
    int 21h

    ; output with Binary type
    mov bx, 0
    mov eax, out_item[bx]
    mov res, eax
    mov cx, 0; the numbers have been put
    call output_2

    jmp end_code

output_10:
    cmp res, 0
    je output_10_end
    
    ; edx = (res - res / 10 * 10) + '0'
    ; res = res / 10
    mov edx, 0
    mov eax, res
    div ten
    mov res, eax
    add dl, '0'
    mov dh, 0
    push dx

    inc cx
    jmp output_10
output_10_end:
    jmp output_stack_10_loop
output_stack_10_loop:
    cmp cx, 0
    je output_stack_10_end
    pop dx
    mov ah, 02h
    int 21h
    dec cx
    jmp output_stack_10_loop
output_stack_10_end:
    ret

output_16:
    cmp res, 0
    je output_16_res
    
    mov edx, 0
    mov eax, res
    div sixt
    mov res, eax
    
    ;dl = mp[dl]
    mov al, dl
    mov bx, offset(mp)
    xlat
    mov dl, al

    mov dh, 0
    push dx

    inc cx
    jmp output_16
output_16_res:
    cmp cx, 8h
    je output_16_end
    mov dl, '0'
    mov dh, 0
    push dx

    inc cx
    jmp output_16_res
output_16_end:
    mov cx, 8h
    jmp output_stack_16_loop
output_stack_16_loop:
    cmp cx, 0
    je output_stack_16_end
    pop dx
    mov ah, 02h
    int 21h
    dec cx
    jmp output_stack_16_loop
output_stack_16_end:
    mov dl, 'h'
    mov ah, 02h
    int 21h
    ret

output_2:
    cmp res, 0
    je output_2_res
    
    mov edx, 0
    mov eax, res
    div two
    mov res, eax
    add dl, '0'
    mov dh, 0
    push dx

    inc cx
    jmp output_2
output_2_res:
    cmp cx, 20h
    je output_2_end
    mov dl, '0'
    mov dh, 0
    push dx

    inc cx
    jmp output_2_res
output_2_end:
    mov cx, 20h
    jmp output_stack_2_loop
output_stack_2_loop:

    pop dx
    mov ah, 02h
    int 21h
    dec cx

    cmp cx, 0h
    je output_stack_2_end

    mov ax, cx
    and ax, 3h
    cmp ax, 0
    je output_space
    jmp output_stack_2_loop
output_space:
    mov dl, ' '
    mov ah, 02h
    int 21h
    jmp output_stack_2_loop

output_stack_2_end:
    mov dl, 'B'
    mov ah, 02h
    int 21h
    ret

end_code:
    ;mov ah, 4Ch
	;int 21h;end the code
code ends
end main

