data segment
s db 100 dup(0)
t db 100 dup(0)
data ends
code segment
assume cs:code, ds:data
main:
	mov ax, data
	mov ds, ax
	mov si, 0;init si
input:
	mov ah, 01h
	int 21h; input
	cmp al, 0Dh; compare with '\r'
	je deal_init; if reach the end of the string, jump to the next part
	mov s[si], al;move the letter into s
	add si, 1;
	loop input
deal_init:
	mov si, 0;si used as the index of s
	mov bx, 0;bx used as the index of t
deal:;identify the type of the letter
	mov cl, s[si]; mov the cl to s[si]
	cmp cl, ' ';compare with ' '
	je addsi; ignore the ' '
	cmp cl, 61h;compare with 'a'
	jge cmp1; continue to judge if the letter is in the range of [a,z]
	cmp cl, 0Dh; compare with '\r'
	je endcx;transform '\r'to '\0'
	jmp psh
addsi:
	add si, 1
	jmp deal
endcx:
	mov cl, 0;change cl to '\0'
	jmp psh
cmp1:
	cmp cl, 7Ah;compare with 'z'
	jg psh;
	sub cx, 20h;change the lowcase into highcase
psh:;move the mov the cl(changed s[si]) to t[bx]
	mov t[bx], cl; 
	add si, 1
	add bx, 1
	cmp cl, 0;judge if reach the end of the s[si]
	jne deal;continue the deal
output_init:
	mov bx, 0;bx used as the index of t
output:
	mov dl, t[bx];in order to output, move t[bx] to dl
	mov ah, 02h
	int 21h;output the letter
	cmp t[bx], 0;
	je output2;
	add bx, 1
	loop output
output2:;output the '\r','\n'
	mov dl, 0Dh
	mov ah, 02h
	int 21h	
	mov dl, 0Ah
	mov ah, 02h
	int 21h
exit:
	mov ah, 4Ch
	int 21h
code ends
end main