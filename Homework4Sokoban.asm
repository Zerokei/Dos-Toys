.386
dgroup group data, code, stk

; define part
UP equ 4800h ; 汇编语言可以调用int 16h/AH=00h      
LEFT equ 4B00h ; 读取上下左右4个方向键及Esc、退格键: 
DOWN equ 5000h ; mov ah, 0                           
RIGHT equ 4D00h ; int 16h; AX=键盘编码                
BKSPACE equ 0E08h ;退格键
MyESC equ 011Bh ; ----------------------------------- */
ROCK equ 0000h ; 仓库外面的石块 
BRICK equ 0001h ; 包围仓库的红色砖块 
BOX equ 0002h ; 箱子 
FLOOR equ 0003h ; 仓库里面的绿色地砖 
BALL equ 0004h ; 球, 用来标注箱子需要存放的位置
MAN equ 0005h ; 推箱子的人, 图像与WALK_UP相同 
BOB equ 0006h ; box on ball, 箱子与球重叠 
PUSH_UP equ 0000h ; 往上推箱子的人 
PUSH_LEFT equ 0001h ; 往左推箱子的人 
PUSH_DOWN equ 0002h ; 往下推箱子的人 
PUSH_RIGHT equ 0003h ; 往右推箱子的人 
WALK_UP equ 0004h ; 往上走的人
WALK_LEFT equ 0005h ; 往左走的人
WALK_DOWN equ 0006h ; 往下走的人
WALK_RIGHT equ 0007h ; 往右走的人
MAX_LEVEL equ 30 ; 最多关卡数

;地图由BLK构成, 如BRICK, BOX, FLOOR, BALL, MAN都是BLK
;blk_ptr指向存放BLK图像的内存块, blk_size表示该内存块的长度
BLK_INFO struc
    blk_size dw 0
    blk_ptr dw 0
BLK_INFO ends

sizeof_SAVE equ 2398
SAVE struc
    _magic db 2 dup(0) ; "BW"
    _level dd 0
    _steps dd 0 ; level, steps 第几关, 已走步数
    _man_x dd 0
    _man_y dd 0 ; man_x, man_y 人的当前坐标, base 1 
    _man_flag dw 0 ; man_flag 人的当前flag
    _flag dw 1Dh*29h ; flag[0x1D][0x29]用来保存当前这关的地图信息, 行数=0x1D, 列数=0x29
SAVE ends


;地图文件的结构
;一个地图文件里面包含11关数据, 其中第1至10关是flag数据(BLK ID), 
;第0关则用来定义11关blk_size_level数据, 同样, blk_size_level[1]
;至blk_size_level[10]对应1至10关, blk_size_level[0]则空置不用;
;地图中每个BLK(即各个flag的图像)的宽度、高度以及地图的行数(纵向
;BLK数量)、列数(横向BLK数量)都用blk_size_level[i]索引:                          
;obj_width[blk_size_level[i]]                    
;obj_height[blk_size_level[i]]                   
;map_rows[blk_size_level[i]]                     
;map_columns[blk_size_level[i]]
;其中i表示当前地图内的第几关(base 1), i = (level-1) % 10 + 1;
;flag[row][col][level_in_map]表示当前地图第level_in_map关中
;第row行(base 1)第col列(base 1)的BLK ID, 如flag[3][4][5]=BOX
;表示当前地图第5关(4,3)坐标处是一个箱子.     
MAP struc
    blk_size_levels dw 0Bh dup(0)
    flags dw 1Dh*29h*0Bh dup(0)
MAP ends

data segment use16

    ;blk_size_level一共有5级: 0, 1, 2, 3, 4
    ;其中0级不用; 各个blk_size_level对应的物体或人的图像宽、高为:
    ;obj_width[blk_size_level]
    ;obj_height[blk_size_level]
    ;以下二维数组的第1维就是blk_size_level;
    ;第2维是指物体或人的BLK ID, 如BRICK, BOX,
    ;FLOOR, PUSH_UP, WALK_UP均为BLK ID.
    blk_size_level dw 0

    palette db 00h, 01h, 02h, 03h, 04h, 05h, 14h, 07h, 38h, 39h, 3Ah, 3Bh, 3Ch, 3Dh, 3Eh, 3Fh
    ;以下数组的下标均为blk_size_level
    obj_width dw 00h, 30h, 20h, 18h, 10h
    obj_height dw 00h, 24h, 18h, 12h, 0Ch
    map_columns dw 00h, 0Dh, 14h, 1Ah, 28h
    map_rows dw 00h, 09h, 0Eh, 13h, 1Ch
    ;箱子个数, 球的个数, 箱子叠球的个数
    box_count dw 0
    ball_count dw 0
    bob_count dw 0

    level dd 0
    steps dd 0 ;第几关(base 1), 已走步数
    level_in_map dd 0 ;当前地图中是第几关(base 1), 一个地图文件里面总共10关
    man_x dd 0
    man_y dd 0
    box_x dd 0
    box_y dd 0 ;人的当前坐标, 刚推好的箱子坐标, base 1
    back_available dd 0 ; 是否允许回退一步
    back_man_flag dw WALK_UP
    man_flag dw WALK_UP ; 人的上一步flag及当前flag
    ox dd 0
    oy dd 0
    nx dd 0
    ny dd 0
    fx dd 0
    fy dd 0
    ;当前坐标(ox,oy), 前一格坐标(nx, ny), 前二格坐标(fx, fy), base 1
    opx dd 0
    opy dd 0
    npx dd 0
    npy dd 0
    fpx dd 0
    fpy dd 0
    ;当前,前一格,前二格的像素坐标, base 0
    back_man_x dd 0
    back_man_y dd 0
    back_box_x dd 0
    back_box_y dd 0
    ;上一步的人坐标及箱子坐标, base 1
    nflag dw 0
    fflag dw 0
    ;地图中某个物体的id称为flag; nflag=前一格的flag, fflag=前二格的flag
    bar_px dd 0
    bar_py dd 0
    ;状态条(用于显示当前关数及步数)的像素坐标
    str_level db 6 dup(0)
    str_steps db 6 dup(0)
    ;当前关数及步数转化成十进制字符串保存在此数组中
    blk_buf dw 0 ; *blk_buf 用来保存人当前踩住的物体的图像, 如FLOOR, BALL 
    pmap dw 0; *pmap 指向地图

    err_message_zero db "Not enough memory!", 0Dh, 0Ah, '$'
    err_message_one db "Not enough memory for blk_buf.", 0Dh, 0Ah, '$'
    err_message_two db "build_blk_info_from_file() failed!", 0Dh, 0Ah, '$'
    err_message_three db "load_map(level) failed!", 0Dh, 0Ah, '$'

    filename1 db "boxdata\\obj\\size0\\flag0.dat",0
    filename2 db "boxdata\\man\\size0\\man0.dat",0
    filename3 db "boxdata\\txt\\txt0.dat",0
    filename4 db "box.sav",0
    filename5 db "boxdata\\map\\lnk0x.map",0
    filename6 db "boxdata\\txt\\txt10.dat",0
    play_status dd 0 ; 建立变量play_status
data ends

code segment use16
assume cs:code, ds:data, ss:stk
main:
    mov fx, 0
    mov fy, 0
    mov eax, 0
    mov ebx, 0
    mov ecx, 0
    mov edx, 0
    mov ax, data
    mov ds, ax
    mov dx, offset dgroup:end_flag
    add dx, 200h
    add dx, 0Fh
    shr dx, 4 
    mov ah, 4Ah
    mov bx, dx
    int 21h   
    mov ah, 48h
    mov bx, 100h
    int 21h    
    jnc success
fail:
    jmp exit
success:

    mov bp, sp
    
    ;blk_buf = farmalloc(4 + (0x30/8+1)*4 * 0x24)
    mov bx, 4+(30h/8+1)*4*24h
    add bx, 0Fh
    shr bx, 4
    mov ah, 48h
    int 21h
    mov blk_buf, ax
    ;if(blk_buf == NULL)
    cmp blk_buf, 0
    jne success1
    mov ah, 9
    mov dx, offset err_message_one
    int 21h
    jmp exit
success1:
    ;build_blk_info_from_file() 
    ;没有写这个
    ;if(load_previous_play_info_from_file("box.sav") == 0) /* no saved play info */
    call load_previous_play_info_from_file;返回值ax
    cmp ax, 0
    jne hav_map
    mov level, 1
    mov level_in_map, 1
    mov steps, 0
    call load_map
    cmp pmap, 0; pmap == 0
    jne success2
    mov dx, offset err_message_three
    int 21h
    jmp exit
success2:
    ;blk_size_level = pmap->blk_size_level[level_in_map]
    mov ax, pmap
    mov es, ax
    mov esi, level_in_map
    shl esi, 1
    mov ax, es:[si].blk_size_levels
    mov blk_size_level, ax
hav_map:
main_loop:
    ;DrawMap_CountObj_SetManXyFlag(man_x, man_y, man_flag);
    mov ax, man_flag
    push ax
    mov eax, man_y
    push eax
    mov eax, man_x
    push eax
    call DrawMap_CountObj_SetManXyFlag
    add sp, 10
    ;If man_x & man_y are not zero, then the above function will draw man 
    ;    on the specified coordinates (man_x, man_y);
    ;    If man_x & man_y are zero, then the above function will search man's 
    ;    coordinates according to the man flag located at original map and 
    ;    finally sets man_x, man_y and man_flag.
    mov back_available, 0
    ;play_status = play()
    call play
    mov play_status, eax
    ;free pmap
    mov ax, pmap
    call freebuf
    ;pmap = NULL
    mov pmap, 0
    ;play_status == -1
    cmp play_status, -1
    je text
    ;level++
    add level, 1
    ;level_in_map = (level - 1) % 10 + 1
    mov eax, level
    mov edx, 0
    add eax, -1
    mov ebx, 10
    div ebx
    mov eax, edx
    add eax, 1
    mov level_in_map, eax
    ;steps = 0
    mov steps, 0
    ;man_x = man_y = man_flag = 0;
    mov man_x, 0
    mov man_y, 0
    mov man_flag, 0
    ;pmap = (MAP *)load_map(level);
    call load_map
    ;if(pmap == NULL)
    cmp pmap, 0
    je fail3
    ;blk_size_level = pmap->blk_size_level[level_in_map]
    mov dx, pmap
    mov es, dx
    mov esi, level_in_map
    shl si, 1
    mov ax, es:[si].blk_size_levels
    mov blk_size_level, ax
main_judge:
    cmp play_status, -1
    jne main_loop
    jmp text 
fail3:
    mov ah, 9
    mov dx, offset err_message_three
    jmp exit
text:
    mov ax, 0003h
    int 10h
exit:
    mov ah, 4Ch
    int 21h

put_obj proc near
;栈传参
;无返回值
p_A EQU word ptr [ebp + 6]
x_A EQU dword ptr [ebp + 8]
y_A EQU dword ptr [ebp + 12]
q_A_offset EQU word ptr [ebp - 2]
q_A_seg EQU word ptr [ebp - 4]
v_A_offset EQU word ptr [ebp - 6]
v_A_seg EQU word ptr [ebp - 8]
pv_A_offset EQU word ptr [ebp - 10]
pv_A_seg EQU word ptr [ebp - 12]
ror_A EQU byte ptr [ebp - 13]
latch_A EQU byte ptr [ebp - 14]
mask_A EQU byte ptr [ebp - 15]
final_byte_mask_A EQU byte ptr [ebp - 16]
tail_mask_A EQU byte ptr [ebp - 17]
and_mask_A EQU byte ptr [ebp - 18]
width_A EQU word ptr [ebp -20]
height_A EQU word ptr [ebp - 22]
bytes_per_line_per_plane_A EQU dword ptr [ebp - 26]
tail_bits_per_line_per_plane_A EQU dword ptr [ebp - 30]
r_A EQU dword ptr [ebp - 34]
plane_A EQU dword ptr [ebp - 38]
i_A EQU dword ptr [ebp - 42]
n_A EQU dword ptr [ebp - 46]

put_obj_start:
    push ebp; 4
    mov ebp, esp
    sub esp, 46
    ;width = *(word far *)p;
    mov ax, p_A
    mov es, ax
    mov ax, es:[0]
    mov width_A, ax
    ;height = *(word far *)(p+2);
    mov ax, es:[2]
    mov height_A, ax
    ;bytes_per_line_per_plane = width / 8;
    mov eax, 0
    mov edx, 0
    mov ax, width_A
    mov ebx, 8
    div ebx
    mov bytes_per_line_per_plane_A, eax
    ;tail_bits_per_line_per_plane = width % 8;
    mov tail_bits_per_line_per_plane_A, edx
    ;v = (byte far *)0xA0000000 + (y * 640L + x) / 8; /* one bit per pixel */
    mov v_A_seg, 0A000h
    mov edx, 0
    mov eax, y_A
    mov ebx, 80
    mul ebx
    mov ebx, x_A
    shr ebx, 3
    add eax, ebx
    mov v_A_offset, ax
    ;ror = x % 8;
    mov eax, x_A
    mov ebx, 8
    div ebx
    mov ror_A, dl
    ;mask = 0xFF >> ror;
    mov ax, 0FFh
    mov cl, ror_A
    shr ax, cl
    mov mask_A, al
    ;q = p+4; /* q->data */
    mov ax, p_A
    mov q_A_seg, ax
    mov q_A_offset, 4

    ;pv = v;  /* pv->(0,0) */
    mov ax, v_A_offset
    mov pv_A_offset, ax
    mov ax, v_A_seg
    mov pv_A_seg, ax
    
    mov r_A, 0; r = 0
    jmp put_obj_judge1
put_obj_loop1:
    mov plane_A, 0
    jmp put_obj_judge2
put_obj_loop2:
    ;select_plane(plane);  
    push plane_A
    call select_plane
    add sp, 4
    ; if (ror != 0)
    cmp ror_A, 0
    jne put_obj_offset1
    ;else /* x coordinate is aligned on the MSB of video byte */
    ;    outportb(0x3CE, 8); /* mask register */
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;    outportb(0x3CF, 0xFF); /* write all 8 bits of one byte without masking */
    mov al, 0FFh
    mov dx, 3CFh
    out dx, al
    ;    outportb(0x3CE, 3); /* ror register */
    mov al, 3h
    mov dx, 3CEh
    out dx, al
    ;    outportb(0x3CF, 0); /* no rotating right */
    mov al, 0
    mov dx, 3CFh
    out dx, al
    ;    movedata(FP_SEG(q), FP_OFF(q), FP_SEG(pv), FP_OFF(pv), bytes_per_line_per_plane);
    ;ds=word ptr q[2];
    ;si=word ptr q[0];
    ;es=word ptr pv[2];
    ;di=word ptr pv[0];
    ;cx=n;
    ;cld
    ;rep movsb
    mov bx, ds; 保存ds
    mov ecx, bytes_per_line_per_plane_A
    mov ds, q_A_seg
    mov si, q_A_offset
    mov es, pv_A_seg
    mov di, pv_A_offset
    cld
    rep movsb
    mov ds, bx; 恢复ds
    ;    n = bytes_per_line_per_plane; /* video bytes written */
    mov eax, bytes_per_line_per_plane_A
    mov n_A, eax
    ;    final_byte_mask = 0x00; /* Since there are no bits left unfilled
    mov final_byte_mask_A, 00h
    jmp put_obj_continue1
put_obj_offset1:
    ;outportb(0x3CE, 8); /* mask register */
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, mask);
    mov al, mask_A
    mov dx, 3CFh
    out dx, al
    ;outportb(0x3CE, 3); /* ror register */
    mov al, 3
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, ror);
    mov al, ror_A
    mov dx, 3CFh
    out dx, al
    ;for(i=0; i<bytes_per_line_per_plane; i++)
    mov i_A, 0
    jmp put_obj_judge3
put_obj_loop3:
    ;    latch = pv[i]; /* There is only one latch for all bytes on one plane, */
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov esi, i_A
    mov al, es:[bx + si]
    mov latch_A, al
    ;    pv[i] = q[i];  /* so we have to latch & write bytes one by one */
    mov esi, i_A
    mov dx, q_A_seg
    mov es, dx
    mov bx, q_A_offset
    mov al, es:[bx + si]

    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov es:[bx + si], al
put_obj_pass3:
    add i_A, 1
put_obj_judge3:
    mov eax, bytes_per_line_per_plane_A
    cmp i_A, eax; i < bytes_per_line_per_plane
    jb put_obj_loop3
    ;outportb(0x3CE, 8); /* mask register */
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, ~mask);
    mov al, mask_A
    not al
    mov dx, 3CFh
    out dx, al
    ;for(i=0; i<bytes_per_line_per_plane; i++)
    mov i_A, 0
    jmp put_obj_judge4
put_obj_loop4:
    ;    latch = pv[i+1];
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov esi, i_A
    add esi, 1
    mov al, es:[bx + si]
    mov latch_A, al
    ;    pv[i+1] = q[i];
    mov esi, i_A
    mov dx, q_A_seg
    mov es, dx
    mov bx, q_A_offset
    mov al, es:[bx + si]

    add si, 1
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov es:[bx + si], al
put_obj_pass4:
    add i_A, 1
put_obj_judge4:
    mov eax, bytes_per_line_per_plane_A
    cmp i_A, eax
    jb put_obj_loop4
    ;n = bytes_per_line_per_plane + 1; /* video bytes written */
    mov eax, bytes_per_line_per_plane_A
    add eax, 1
    mov n_A, eax
    ;final_byte_mask = mask;  /* 1 = bit to be filled; 0 = bit already filled */
    mov al, mask_A
    mov final_byte_mask_A, al
put_obj_continue1:
    ;q += bytes_per_line_per_plane;
    mov ax, q_A_offset
    add eax, bytes_per_line_per_plane_A
    mov q_A_offset, ax
    ;if(tail_bits_per_line_per_plane != 0)
    cmp tail_bits_per_line_per_plane_A, 0
    jne put_obj_offset2
    jmp put_obj_continue2
put_obj_offset2: 
    ;tail_mask = (1 << tail_bits_per_line_per_plane) - 1;
    mov al, 1
    mov ecx, tail_bits_per_line_per_plane_A
    shl al, cl
    sub al, 1
    mov tail_mask_A, al    
    ;tail_mask = tail_mask << (8-tail_bits_per_line_per_plane);
    mov al, tail_mask_A
    mov ecx, 8
    sub ecx, tail_bits_per_line_per_plane_A
    shl al, cl
    mov tail_mask_A, al
    ;tail_mask = tail_mask >> ror | tail_mask << (8-ror);
    mov cl, ror_A
    mov al, tail_mask_A
    shr al, cl
    mov bl, al
    mov cl, 8
    sub cl, ror_A
    mov al, tail_mask_A
    shl al, cl
    mov tail_mask_A, al
    or tail_mask_A, bl
    ;and_mask = final_byte_mask & tail_mask;
    mov al, tail_mask_A
    and al, final_byte_mask_A
    mov and_mask_A, al    
    ;outportb(0x3CE, 8); /* mask register */
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, and_mask);
    mov al, and_mask_A
    mov dx, 3CFh
    out dx, al
    ;outportb(0x3CE, 3); /* ror register */
    mov al, 3
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, ror);
    mov al, ror_A
    mov dx, 3CFh
    out dx, al
    ;latch = pv[n-1];
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov esi, n_A
    sub si, 1
    mov al, es:[bx + si]
    mov latch_A, al
    ;pv[n-1] = *q;
    mov dx, q_A_seg
    mov es, dx
    mov bx, q_A_offset
    mov si, 0
    mov al, es:[bx + si]
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov esi, n_A
    sub si, 1
    mov es:[bx + si], al
    ;tail_mask ^= and_mask; /* calculate the remaining bits */
    mov al, and_mask_A
    xor tail_mask_A, al
    ;if(tail_mask != 0) /* some bits left in *q should be copied to next video byte */
    cmp tail_mask_A, 0
    jne put_obj_offset3
    jmp put_obj_continue3
put_obj_offset3:
    ;    outportb(0x3CE, 8); /* mask register */
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;    outportb(0x3CF, tail_mask);
    mov al, tail_mask_A
    mov dx, 3CFh
    out dx, al
    ;    latch = pv[n];
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov esi, n_A
    mov al, es:[bx + si]
    mov latch_A, al
    ;    pv[n] = *q;
    mov dx, q_A_seg
    mov es, dx
    mov bx, q_A_offset
    mov si, 0
    mov al, es:[bx + si]
    mov dx, pv_A_seg
    mov es, dx
    mov bx, pv_A_offset
    mov esi, n_A
    mov es:[bx + si], al
put_obj_continue3:
    ;q++; /* skip this used byte */
    add q_A_offset, 1
put_obj_continue2:
put_obj_pass2:
    add plane_A, 1
put_obj_judge2:
    cmp plane_A, 4
    jb put_obj_loop2
put_obj_loop1_1:
    ;pv += 640/8; /* adjust pv such that it will point to next line's 1st pixel */
    add pv_A_offset, 80
put_obj_pass1:
    add r_A, 1
put_obj_judge1:
    mov eax, 0
    mov ax, height_A
    cmp r_A, eax
    jb put_obj_loop1
put_obj_part2:
    ;outportb(0x3CE, 8); /* mask register */
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, 0xFF);
    mov al, 0FFh
    mov dx, 3CFh
    out dx, al
    ;outportb(0x3CE, 3); /* ror register */
    mov al, 3
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, 0);
    mov al, 0
    mov dx, 3CFh
    out dx, al
    ;free(p)
    mov ax, p_A
    call freebuf
put_obj_end:
    mov esp, ebp
    pop ebp
    ret
put_obj endp

read_file proc near
;栈顶 offset filename, seg filename
;返回ax p
;ebx n
filename_offset EQU word ptr [ebp - 2] ;定义 offset filename
filename_seg EQU word ptr [ebp - 4] ;定义seg filename
fp_2 EQU word ptr [ebp - 6] ;定义fp
p_2_seg EQU word ptr [ebp - 8] ;定义p
size_2 EQU word ptr [ebp - 10] ;定义size
    push ds; 2byte
    push ebp; 4byte
    mov ebp, esp
    sub esp, 10

    mov ax, [ebp + 8]
    mov filename_seg, ax
    mov ax, [ebp + 10]
    mov filename_offset, ax
    ;fp = fopen(filename, "rb")
    mov dx, filename_offset
    mov ax, filename_seg
    mov ds, ax
    mov ax, 3D00h
    int 21h; AX = fp
    mov fp_2, ax
    ;if(fp == NULL)
    cmp fp_2, 0
    je offset1
    ;fseek(fp, 0, SEEK_END)
    mov ax, 4202h
    mov bx, fp_2
    xor cx, cx
    xor dx, dx
    int 21h ; DX:AX=size
    mov size_2, ax
    ;fseek(fp, 0, SEEK_SET)
    mov ax, 4200h
    mov bx, fp_2
    xor cx, cx
    xor dx, dx
    int 21h ; DX:AX=0
    ;p = malloc(size)
    mov ah, 48h
    mov bx, size_2
    add bx, 0Fh
    shr bx, 4
    int 21h
    mov p_2_seg, ax
    cmp p_2_seg, 0
    je offset2
    ;fread(p, 1, size, fp)
    mov bx, fp_2
    mov cx, size_2
    mov dx, 0
    mov ax, p_2_seg
    mov ds, ax
    mov ah, 3Fh
    int 21h
    ;fclose(fp)
    mov ah, 3Eh
    mov bx, fp_2
    int 21h
    
    mov ax, p_2_seg
    mov ebx, 0
    mov bx, size_2
read_file_ret:
    mov esp, ebp
    pop ebp
    pop ds
    ret
offset2:
    mov ah, 3Eh
    mov bx, fp_2
    int 21h
offset1:
    mov esp, ebp
    pop ebp
    pop ds
    mov ax, 0; return NULL
    mov ebx, 0; *n = 0
    ret

read_file endp

vga proc near
;无传参
;无返回值
vga_start:
    ;_AX=0x0012
    ;geninterrupt(0x10)
    mov ax, 12h
    int 10h
    ;outportb(0x3CE, 5)
    mov al, 5
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, 0x00)
    mov al, 0
    mov dx, 3CFh
    out dx, al
    ;outportb(0x3CE, 8)
    mov al, 8
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, 0xFF)
    mov al, 0FFh
    mov dx, 3CFh
    out dx, al
    ;outportb(0x3CE, 3)
    mov al, 3
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, 0)
    mov al, 0
    mov dx, 3CFh
    out dx, al
    ;
    ret
vga endp

set_palette proc near
; 直接引用palette
    mov ax, ds
    mov es, ax
    mov dx, offset palette
    mov bx, 0
    mov ax, 1002h
    int 10h
    ret
set_palette endp

load_map proc near
;level 为全局变量
;无返回值

n_4 EQU dword ptr [ebp - 4]
map_file_idx EQU dword ptr [ebp - 8]

load_map_start:
    push ebp
    mov ebp, esp
    sub esp, 8
load_map_cmp:
    cmp level, MAX_LEVEL
    jbe load_map_continue
    mov level, 1; level = 1
load_map_continue:
    ;map_file_idx = (level-1) / 10
    mov eax, level
    sub eax, 1
    mov edx, 0
    mov ebx, 10
    div ebx
    mov map_file_idx, eax
    ;map_file[map_file_idx]
    mov eax, map_file_idx
    add eax, '0'
    add al, 1
    mov [filename5+17], al
    ;pmap = read_file(map_file[map_file_idx], &n);
    mov ax, offset filename5
    push ax
    push ds
    call read_file
    mov n_4, ebx
    mov pmap, ax
load_map_end:
    mov esp, ebp
    pop ebp
    ret
load_map endp

load_previous_play_info_from_file proc near
;传入的参数已被设定为全局变量
;返回值约定为ax
ps_5 EQU word ptr [ebp - 2]
fp_5 EQU word ptr [ebp - 4]
n_5 EQU dword ptr [ebp - 8]
x_5 EQU dword ptr [ebp - 12]
y_5 EQU dword ptr [ebp - 16]
load_previous_play_info_from_file_start:
    push ds
    push ebp
    mov ebp, esp
    sub esp, 16
    ;fp = fopen(filename, "rb")
    
    mov ax, 3D00h
    mov dx, offset filename4
    int 21h
    mov fp_5, ax
    ;if(fp == NULL)
    ;cmp fp_5, 2
    jc load_previous_play_info_from_file_fail
    ;ps = malloc(sizeof (SAVE))
    mov ah, 48h
    mov bx, sizeof_SAVE
    add bx, 0Fh
    shr bx, 4
    int 21h
    mov ps_5, ax
    ;if(ps == NULL)
    cmp ps_5, 0
    je load_previous_play_info_from_file_fail
    ;n = fread(ps, 1, sizeof(SAVE), fp)
    mov ax, ds
    mov es, ax
    mov eax, 0
    mov ah, 3Fh
    mov bx, fp_5
    mov cx, sizeof_SAVE
    mov dx, 0
    mov ds, ps_5
    int 21h
    mov n_5, eax
    mov ax, es
    mov ds, ax
    ;fclose(fp)
    mov ah, 3Eh
    mov bx, fp_5
    int 21h
    ;if(n<sizeof (SAVE))
    cmp n_5, sizeof_SAVE
    mov ebx, n_5
    jne load_previous_play_info_from_file_fail
    ;if(*(word *)ps->magic != 0x5742) /* check "BW" */
    mov dx, ps_5
    mov es, dx
    mov ax, 5742h
    cmp word ptr es:[0], ax
    jne load_previous_play_info_from_file_fail
    ;level = ps->level
    mov dx, ps_5
    mov es, dx
    mov eax, es:[0]._level
    mov level, eax
    ;level_in_map = (level - 1) % 10 + 1;
    mov eax, level
    sub eax, 1
    mov edx, 0
    mov ecx, 10
    div ecx
    mov level_in_map, edx
    add level_in_map, 1
    ;steps = ps->steps
    mov dx, ps_5
    mov es, dx
    mov eax, es:[0]._steps
    mov steps, eax
    ;pmap = (MAP *)load_map(level)
    call load_map
    ;if(pmap == NULL)
    cmp pmap, 0
    je load_previous_play_info_from_file_fail
    ;blk_size_level = pmap->blk_size_level[level_in_map]
    mov dx, pmap
    mov es, dx
    mov esi, level_in_map
    shl si, 1; si = si * 2
    mov ax, es:[si].blk_size_levels
    mov blk_size_level, ax

lp_begin1:
    mov y_5, 1
    jmp lp_judge1
lp_loop1:
    mov x_5, 1
    jmp lp_judge2
lp_loop2:
    ; pmap->flag[y][x][level_in_map] = ps->flag[y][x];
    mov dx, ps_5
    mov es, dx
    mov eax, y_5
    mov bx, 29h
    mul bx
    add eax, x_5
    mov si, ax
    shl si, 1; si = si * 2
    mov ax, es:[si]._flag ; ps->flag[y][x]
    push ax
    push level_in_map
    push x_5
    push y_5
    call assign_pmap_flag
    add sp, 14

    ;copy map info from saved map to original map
lp_pass2:
    add x_5, 1
lp_judge2:
    ; x <= map_columns[blk_size_level]
    call find_map_columns_number
    cmp x_5, eax
    jbe lp_loop2
lp_pass1:
    add y_5, 1
lp_judge1:
    ; y <= map_rows[blk_size_level]
    call find_map_rows_number
    cmp y_5, eax
    jbe lp_loop1
lp_begin_2:
    mov dx, ps_5
    mov es, dx
    ;man_x = ps->man_x
    mov eax, es:[0]._man_x
    mov man_x, eax
    ;man_y = ps->man_y
    mov eax, es:[0]._man_y
    mov man_y, eax
    ;man_flag = ps->man_flag
    mov ax, es:[0]._man_flag
    mov man_flag, ax
    ;free(ps)
    mov ax, ps_5
    call freebuf
    ;return 1
    mov ax, 1
load_previous_play_info_from_file_end:
    ;return
    mov esp, ebp
    pop ebp
    pop ds
    ret
load_previous_play_info_from_file_fail:
    ;return 0
    mov ax, 0
    jmp load_previous_play_info_from_file_end

load_previous_play_info_from_file endp

DrawMap_CountObj_SetManXyFlag proc near
;栈传参 mx, my, mflag
mflag_B EQU word ptr [ebp + 12]
my_B EQU dword ptr [ebp + 10]
mx_B EQU dword ptr [ebp + 6]
;int x, y, man_px, man_py;
x_B EQU dword ptr [ebp - 4]
y_B EQU dword ptr [ebp - 8]
man_px_B EQU dword ptr [ebp - 12]
man_py_B EQU dword ptr [ebp - 16]
;word flag
flag_B EQU word ptr [ebp - 18]
DrawMap_CountObj_SetManXyFlag_start:
    push ebp; 4
    mov ebp, esp
    sub esp, 18
    ;ball_count = 0;
    mov ball_count, 0
    ;box_count = 0;
    mov box_count, 0
    ;bob_count = 0;
    mov bob_count, 0
    ;vga(); /* 切换到640*480*16color图形模式 */
    call vga
    ;set_palette(&palette[0]); /* 设置调色板 */
    call set_palette
    ;for(y=1; y<=map_rows[blk_size_level]; y++)
    mov y_B, 1
    jmp DrawMap_CountObj_SetManXyFlag_judge1
DrawMap_CountObj_SetManXyFlag_loop1:
    ;  for(x=1; x<=map_columns[blk_size_level]; x++)
    mov x_B, 1; x = 1
    jmp DrawMap_CountObj_SetManXyFlag_judge2
DrawMap_CountObj_SetManXyFlag_loop2:
    ; flag = pmap->flag[y][x][level_in_map];
    mov eax, level_in_map
    push eax
    mov eax, x_B
    push eax
    mov eax, y_B
    push eax
    call find_pmap_flag
    add sp, 12
    mov flag_B, ax;/* flag = *(word *)((byte *)pmap+((0x29*y+x)*0x0B+level)*2); */
    ;     if(flag == MAN) /* the original map contains MAN flag, the saved map does not */
    cmp flag_B, MAN
    jne DrawMap_CountObj_SetManXyFlag_offset1
    ;        man_x = x; /* base 1 */
    mov eax, x_B
    mov man_x, eax
    ;        man_y = y; /* base 1 */
    mov eax, y_B
    mov man_y, eax
    ;        man_flag = WALK_UP; /* 原始地图里的人的flag一定是WALK_UP */
    mov man_flag, WALK_UP
    ;        flag = FLOOR; /* 在人换成FLOOR并显示在地图上 */
    mov flag_B, FLOOR
    ;        pmap->flag[y][x][level_in_map] = FLOOR; 
    ;        /* 原始地图里的人踩住的物体一定是FLOOR, 不可能是BALL. */    mov ax, FLOOR
    mov ax, FLOOR
    push ax
    mov eax, level_in_map
    push eax
    mov eax, x_B
    push eax
    mov eax, y_B
    push eax
    call assign_pmap_flag
    add sp, 14
    jmp DrawMap_CountObj_SetManXyFlag_continue1
DrawMap_CountObj_SetManXyFlag_offset1:
    ;     else if(flag == BALL)
    cmp flag_B, BALL
    jne DrawMap_CountObj_SetManXyFlag_offset2
    ; ball_count++;
    add ball_count, 1 
    jmp DrawMap_CountObj_SetManXyFlag_continue1
DrawMap_CountObj_SetManXyFlag_offset2:
    ;     else if(flag == BOX)
    cmp flag_B, BOX
    jne DrawMap_CountObj_SetManXyFlag_offset3
    ;        box_count++;
    add box_count, 1
    jmp DrawMap_CountObj_SetManXyFlag_continue1    
DrawMap_CountObj_SetManXyFlag_offset3:
    ;     else if(flag == BOB)
    cmp flag_B, BOB
    jne DrawMap_CountObj_SetManXyFlag_continue1
    ;        ball_count++;
    add ball_count, 1
    ;        box_count++;
    add box_count, 1
    ;        bob_count++;
    add bob_count, 1
    jmp DrawMap_CountObj_SetManXyFlag_continue1
DrawMap_CountObj_SetManXyFlag_continue1:
    ;    /*=*/ (y-1) * obj_height[blk_size_level]); /* 画flag对应的BLK */
    mov eax, y_B
    push eax
    call x_subone_height
    add sp, 4
    push eax
    ;     /*=*/ (x-1) * obj_width[blk_size_level],
    mov eax, x_B
    push eax
    call x_subone_width
    add sp, 4
    push eax
    ;     put_obj(obj_blk[blk_size_level][flag].blk_ptr,
    mov ax, flag_B
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    ;put_obj
    call put_obj
    add sp, 10
DrawMap_CountObj_SetManXyFlag_pass2:
    add x_B, 1
DrawMap_CountObj_SetManXyFlag_judge2:
    call find_map_columns_number
    cmp x_B, eax
    jbe DrawMap_CountObj_SetManXyFlag_loop2
DrawMap_CountObj_SetManXyFlag_pass1:
    add y_B, 1
DrawMap_CountObj_SetManXyFlag_judge1:
    call find_map_rows_number
    cmp y_B, eax
    jbe DrawMap_CountObj_SetManXyFlag_loop1
    ;if(mx != 0 && my != 0) /* when map info is from "box.sav", not from original map */
    cmp mx_B, 0
    je DrawMap_CountObj_SetManXyFlag_offset4
    cmp my_B, 0
    je DrawMap_CountObj_SetManXyFlag_offset4
    ;  man_x = mx;         /* 把box.sav中获取的人的坐标及flag保存到全局变量中 */
    mov eax, mx_B
    mov man_x, eax
    ;  man_y = my;
    mov eax, my_B
    mov man_y, eax
    ;  man_flag = mflag;
    mov ax, mflag_B
    mov man_flag, ax
DrawMap_CountObj_SetManXyFlag_offset4:
    ;man_px = (man_x-1) * obj_width[blk_size_level];
    mov eax, man_x
    push eax
    call x_subone_width
    add sp, 4
    mov man_px_B, eax
    ;man_py = (man_y-1) * obj_height[blk_size_level];
    mov eax, man_y
    push eax
    call x_subone_height
    add sp, 4
    mov man_py_B, eax
    ;get_obj(blk_buf, man_px, man_py, obj_width[blk_size_level], obj_height[blk_size_level]);
    ;/* 保存人当前踩住的物体图像到blk_buf指向的内存块中 */
    mov eax, man_y
    mov ebx, man_x
    call get_obj
    ;put_obj(man_blk[blk_size_level][man_flag].blk_ptr, man_px, man_py);
    ;/* 在(man_x, man_y)处画人 */
    mov eax, man_py_B
    push eax
    mov eax, man_px_B
    push eax
    ;man_blk[blk_size_level][man_flag].blk_ptr
    mov ax, man_flag
    push ax
    call find_man_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;bar_py = map_rows[blk_size_level] * obj_height[blk_size_level] + 4;
    call find_height
    mov bar_py, eax
    call find_map_rows_number
    mov ecx, bar_py
    mov edx, 0
    mul ecx
    add eax, 4
    mov bar_py, eax
    ;bar_px = (map_columns[blk_size_level] * obj_width[blk_size_level]
    ;	    - *(word far *)txt_blk[10].blk_ptr) / 2;
    ;/* ---^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^--- bar's width */
    call find_width
    mov bar_px, eax
    call find_map_columns_number
    mov edx, 0
    mov ecx, bar_px
    mul ecx
    mov bar_px, eax
    call load_txt_ten_ptr
    mov es, ax; ax = txt_blk[10].blk_ptr
    mov eax, 0
    mov ax, word ptr es:[0]
    sub bar_px, eax
    mov eax, bar_px
    shr eax, 1
    mov bar_px, eax
    ;put_obj(txt_blk[10].blk_ptr, bar_px, bar_py);
    mov eax, bar_py
    push eax
    mov eax, bar_px
    push eax
    mov ax, es; es = txt_blk[10].blk_ptr
    push ax
    call put_obj
    add sp, 10
    ;draw_level_and_steps(); /* 显示当前关数及步数 */
    call draw_level_and_steps
DrawMap_CountObj_SetManXyFlag_end:
    mov esp, ebp
    pop ebp
    ret
DrawMap_CountObj_SetManXyFlag endp

assign_pmap_flag proc near
;pmap->flag[nx][ny][level_in_map] = value
value_f EQU word ptr [esp + 14]
level_in_map_f EQU dword ptr [esp + 10]
ny_f EQU dword ptr [esp + 6]
nx_f EQU dword ptr [esp + 2]

assign_pmap_flag_start:
    mov ax, pmap
    mov es, ax
    mov bx, 0
    ;nx * 0Bh * 29h
    mov edx, 0
    mov eax, nx_f
    mov ebx, 0Bh*29h
    mul ebx
    mov esi, eax
    ;ny * 0Bh
    mov edx, 0
    mov eax, ny_f
    mov ebx, 0Bh
    mul ebx
    add esi, eax
    ;level_in_map
    add esi, level_in_map
    shl esi, 1
assign_pmap_flag_end:
    mov ax, value_f
    mov word ptr es:[si].flags, ax
    ret
assign_pmap_flag endp

find_pmap_flag proc near
;pmap->flag[nx][ny][level_in_map]
;ax返回值
level_in_map_f EQU dword ptr [esp + 10]
ny_f EQU dword ptr [esp + 6]
nx_f EQU dword ptr [esp + 2]

find_pmap_flag_start:
    mov dx, pmap
    mov es, dx
    mov bx, 0
    ;nx * 0Bh * 29h
    mov edx, 0
    mov eax, nx_f
    mov ebx, 0Bh*29h
    mul ebx
    mov esi, eax
    ;ny * 0Bh
    mov edx, 0
    mov eax, ny_f
    mov ebx, 0Bh
    mul ebx
    add esi, eax
    ;level_in_map
    add esi, level_in_map
    shl esi, 1
find_pmap_flag_end:
    mov ax, word ptr es:[si].flags  
    ret
find_pmap_flag endp

x_subone_width proc near
; (x-1)*obj_width[blk_size_level]
; 返回值为eax
x_xw EQU dword ptr [esp + 2]
    mov bx, offset obj_width
    mov si, blk_size_level
    shl si, 1
    mov edx, 0
    mov eax, 0
    mov ax, [bx + si]
    mov ebx, x_xw
    sub ebx, 1
    mul ebx
    ret
x_subone_width endp

x_subone_height proc near
; (x-1)*obj_height[blk_size_level]
; 返回值为eax
x_xh EQU dword ptr [esp + 2]
    mov bx, offset obj_height
    mov si, blk_size_level
    shl si, 1
    mov edx, 0
    mov eax, 0
    mov ax, [bx + si]
    mov ebx, x_xh
    sub ebx, 1
    mul ebx
    ret
x_subone_height endp

find_width proc near
;obj_width[blk_size_level]
;返回值ax
    mov bx, offset obj_width
    mov si, blk_size_level
    shl si, 1
    mov ax, [bx + si]
    ret
find_width endp

find_height proc near
;obj_height[blk_size_level]
;返回值ax
    mov bx, offset obj_height
    mov si, blk_size_level
    shl si, 1
    mov ax, [bx + si]
    ret
find_height endp

find_man_blk_ptr proc near
;man_blk[blk_size_level][x_flag].blk_ptr
;传参x_flag
;返回值为ax
x_flag0 EQU word ptr [esp + 2]
    mov ax, blk_size_level
    mov bx, x_flag0
    call load_man_ptr
    ret
find_man_blk_ptr endp

find_obj_blk_ptr proc near
;obj_blk[blk_size_level][x_flag].blk_ptr
; 传参x_flag
; 返回值ax
x_flag1 EQU word ptr [esp + 2]
    mov ax, blk_size_level
    mov bx, x_flag1
    call load_obj_ptr
    ret
find_obj_blk_ptr endp

find_map_columns_number proc near
;eax 作为返回值
;return map_columns[blk_size_level]
    mov bx, offset map_columns
    mov si, blk_size_level
    shl si, 1
    mov eax, 0
    mov ax, word ptr [bx + si]
    ret
find_map_columns_number endp

find_map_rows_number proc near
;eax 作为返回值
;return map_rows[blk_size_level]
    mov bx, offset map_rows
    mov si, blk_size_level
    shl si, 1
    mov eax, 0
    mov ax, word ptr [bx + si]
    ret
find_map_rows_number endp

load_man_ptr proc near
;al,bl 传入数字
;ax 传出偏移地址
    add al, '0'
    mov [filename2 + 18], al
    add bl, '0'
    mov [filename2 + 24], bl
    mov ax, offset filename2
    push ax
    push ds
    call read_file
    add sp, 4
    ret
load_man_ptr endp

load_obj_ptr proc near
;al,bl 传入数字
;ax 传出偏移地址
    add al, '0'
    mov [filename1+18], al
    add bl, '0'
    mov [filename1+25], bl
    mov ax, offset filename1
    push ax
    push ds
    call read_file
    add sp, 4
    ret
load_obj_ptr endp

load_txt_ptr proc near
;al 传入数字
;ax 传出偏移地址
    add al, '0'
    mov [filename3+17], al
    mov ax, offset filename3
    push ax
    push ds
    call read_file
    add sp, 4
    ret
load_txt_ptr endp

load_txt_ten_ptr proc near
    mov ax, offset filename6
    push ax
    push ds
    call read_file
    add sp, 4
    ret
load_txt_ten_ptr endp

select_plane proc near
n_se EQU dword ptr [esp + 2]
;利用栈传参 int n
;无返回值
    ;outportb(0x3CE, 4)
    mov al, 4
    mov dx, 3CEh
    out dx, al
    ;outportb(0x3CF, n)
    mov eax, n_se
    mov dx, 3CFh
    out dx, al
    ;outportb(0x3C4, 2)
    mov al, 2
    mov dx, 3C4h
    out dx, al
    ;outportb(0x3C5, 1<<n)
    mov al, 1
    mov ecx, n_se
    shl al, cl
    mov dx, 3C5h
    out dx, al

    ret
select_plane endp

play proc near
;eax返回值
i_3 EQU dword ptr [ebp - 4]
n_3 EQU dword ptr [ebp - 8]
result_3 EQU dword ptr [ebp - 12]
key_3 EQU word ptr [ebp - 14]
play_start:
    push ebp
    mov ebp, esp
    sub esp, 14

    mov result_3, 0
play_loop:
    ;键盘中断
    mov ah, 0
    int 16h
    cmp ax, UP
    je call_go_up
    cmp ax, LEFT
    je call_go_left
    cmp ax, DOWN
    je call_go_down
    cmp ax, RIGHT
    je call_go_right
    cmp ax, BKSPACE
    je call_go_back
    cmp ax, MyESC
    je call_go_esc
    jmp play_loop
call_go_up:
    call go_up
    mov result_3, eax
    jmp play_judge
call_go_left:   
    call go_left
    mov result_3, eax
    jmp play_judge
call_go_down:
    call go_down
    mov result_3, eax
    jmp play_judge
call_go_right:
    call go_right
    mov result_3, eax
    jmp play_judge
call_go_back:
    call go_back
    mov result_3, eax
    jmp play_judge
call_go_esc:
    call go_esc
    mov result_3, eax
    jmp play_judge
play_judge:
    ;result != -1 && result != 2
    cmp result_3, -1
    je play_end
    cmp result_3, 2
    je play_end
    jmp play_loop
play_end:
    mov eax, result_3
    mov esp, ebp
    pop ebp
    ret
play endp

go_up proc near
;无传入值, 用eax返回
    ; ox = man_x
    mov eax, man_x
    mov ox, eax
    ; oy = man_y
    mov eax, man_y
    mov oy, eax
    ; nx = man_x
    mov eax, man_x
    mov nx, eax
    ; ny = man_y - 1
    mov eax, man_y
    sub eax, 1
    mov ny, eax
    ; fx = man_x 
    mov eax, man_x
    mov fx, eax
    ; fy = man_y - 2
    mov eax, man_y
    sub eax, 2
    mov fy, eax
    ; return do_walk_or_push(WALK_UP, PUSH_UP)
    mov ax, PUSH_UP
    push ax
    mov ax, WALK_UP
    push ax
    call do_walk_or_push
    add sp, 4
    ;返回值为eax
    ret
go_up endp

go_left proc near
    ; ox = man_x
    mov eax, man_x
    mov ox, eax
    ; oy = man_y
    mov eax, man_y
    mov oy, eax
    ; nx = man_x - 1
    mov eax, man_x
    sub eax, 1
    mov nx, eax
    ; ny = man_y
    mov eax, man_y
    mov ny, eax
    ; fx = man_x - 2
    mov eax, man_x
    sub eax, 2
    mov fx, eax
    ; fy = man_y
    mov eax, man_y
    mov fy, eax
    ; return do_walk_or_push(WALK_LEFT, PUSH_LEFT)
    mov ax, PUSH_LEFT
    push ax
    mov ax, WALK_LEFT
    push ax
    call do_walk_or_push
    add sp, 4
    ;返回值为eax
    ret
go_left endp

go_down proc near
    ; ox = man_x
    mov eax, man_x
    mov ox, eax
    ; oy = man_y
    mov eax, man_y
    mov oy, eax
    ; nx = man_x
    mov eax, man_x
    mov nx, eax
    ; ny = man_y + 1
    mov eax, man_y
    add eax, 1
    mov ny, eax
    ; fx = man_x
    mov eax, man_x
    mov fx, eax
    ; fy = man_y + 2
    mov eax, man_y
    add eax, 2
    mov fy, eax
    ; return do_walk_or_push(WALK_DOWN, PUSH_DOWN)
    mov ax, PUSH_DOWN
    push ax
    mov ax, WALK_DOWN
    push ax
    call do_walk_or_push
    ;返回值为eax
    add sp, 4
    ret
go_down endp

go_right proc near
    ; ox = man_x
    mov eax, man_x
    mov ox, eax
    ; oy = man_y
    mov eax, man_y
    mov oy, eax
    ; nx = man_x + 1
    mov eax, man_x
    add eax, 1
    mov nx, eax
    ; ny = man_y
    mov eax, man_y
    mov ny, eax
    ; fx = man_x + 2
    mov eax, man_x
    add eax, 2
    mov fx, eax
    ; fy = man_y
    mov eax, man_y
    mov fy, eax
    ; return do_walk_or_push(WALK_RIGHT, PUSH_RIGHT)
    mov ax, PUSH_RIGHT
    push ax
    mov ax, WALK_RIGHT
    push ax
    call do_walk_or_push
    add sp, 4
    ;返回值为eax
    ret
go_right endp

go_back proc near
;无传参
;返回值使用eax
bx_8 EQU dword ptr [ebp - 4]
by_8 EQU dword ptr [ebp - 8]
bpx_8 EQU dword ptr [ebp - 12]
bpy_8 EQU dword ptr [ebp - 16]
go_back_start:
    push ebp
    mov ebp, esp
    sub esp, 16

    ; if (!back_available)
    cmp back_available, 0
    je go_back_fail
    ; ox = man_x
    mov eax, man_x
    mov ox, eax
    ; oy = man_y
    mov eax, man_y
    mov oy, eax
    ; bx = box_x
    mov eax, box_x
    mov bx_8, eax
    ; by = box_y
    mov eax, box_y
    mov by_8, eax
    ; opx = (ox - 1) * obj_width[blk_size_level]
    push ox
    call x_subone_width
    add sp, 4
    mov opx, eax
    ; opy = (oy-1) * obj_height[blk_size_level]
    push oy
    call x_subone_height
    add sp, 4
    mov opy, eax
    ; bpx = (bx - 1) * obj_width[blk_size_level]
    push bx_8
    call x_subone_width
    add sp, 4
    mov bpx_8, eax
    ; bpy = (by - 1) * obj_height[blk_size_level]
    push by_8
    call x_subone_height
    add sp, 4
    mov bpy_8, eax
    ;put_obj(blk_buf, opx, opy); /* hide man */
    push opy
    push opx
    push blk_buf
    call put_obj
    add sp, 10
    ;if(pmap->flag[by][bx][level_in_map] == BOB) /* recover ball */
    push level_in_map
    push bx_8
    push by_8
    call find_pmap_flag
    add sp, 12
    cmp ax, BOB
    je go_back_offset1
    ;put_obj(obj_blk[blk_size_level][FLOOR].blk_ptr, bpx, bpy)
    push bpy_8
    push bpx_8
    mov ax, FLOOR
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;pmap->flag[by][bx][level_in_map] = FLOOR;
    mov ax, FLOOR
    push ax
    push level_in_map
    push bx_8
    push by_8
    call assign_pmap_flag
    add sp, 14
    jmp go_back_offset1_end
go_back_offset1:
    ;put_obj(obj_blk[blk_size_level][BALL].blk_ptr, bpx, bpy)
    push bpy_8
    push bpx_8
    mov ax, BALL
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;pmap->flag[by][bx][level_in_map] = BALL
    mov ax, BALL
    push ax
    push level_in_map
    push bx_8
    push by_8 
    call assign_pmap_flag
    add sp, 14
    ;bob_count--
    sub bob_count, 1
go_back_offset1_end:
    ;ox=back_man_x, oy=back_man_y
    mov eax, back_man_x
    mov ox, eax
    mov eax, back_man_y
    mov oy, eax
    ;bx=back_box_x, by=back_box_y
    mov eax, back_box_x
    mov bx_8, eax
    mov eax, back_box_y
    mov by_8, eax
    ; opx = (ox - 1) * obj_width[blk_size_level]
    push ox
    call x_subone_width
    add sp, 4
    mov opx, eax
    ; opy = (oy-1) * obj_height[blk_size_level]
    push oy
    call x_subone_height
    add sp, 4
    mov opy, eax
    ; bpx = (bx - 1) * obj_width[blk_size_level]
    push bx_8
    call x_subone_width
    add sp, 4
    mov bpx_8, eax
    ; bpy = (by - 1) * obj_height[blk_size_level]
    push by_8
    call x_subone_height
    add sp, 4
    mov bpy_8, eax
    
    ;get_obj(blk_buf, opx, opy, obj_width[blk_size_level], obj_height[blk_size_level]);
    mov eax, oy
    mov ebx, ox
    call get_obj
    ;put_obj(man_blk[blk_size_level][back_man_flag].blk_ptr, opx, opy); /* draw man */
    push opy
    push opx
    push back_man_flag
    call find_man_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;if (pmap->flag[by][bx][level_in_map] == BALL)
    push level_in_map
    push bx_8
    push by_8
    call find_pmap_flag
    add sp, 12
    cmp ax, BALL
    je go_back_offset2
    ;put_obj(obj_blk[blk_size_level][BOX].blk_ptr, bpx, bpy)
    push bpy_8
    push bpx_8
    mov ax, BOX
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;pmap->flag[by][bx][level_in_map] = BOX;
    mov ax, BOX
    push ax
    push level_in_map
    push bx_8
    push by_8
    call assign_pmap_flag
    add sp, 14
    jmp go_back_offset2_end
go_back_offset2:
    ;put_obj(obj_blk[blk_size_level][BOB].blk_ptr, bpx, bpy)
    push bpy_8
    push bpx_8
    mov ax, BOB
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;pmap->flag[by][bx][level_in_map] = BOB
    mov ax, BOB
    push ax
    push level_in_map
    push bx_8
    push by_8
    call assign_pmap_flag
    add sp, 14
go_back_offset2_end:
    ;man_x = ox
    mov eax, ox
    mov man_x, eax
    ;man_y = oy
    mov eax, oy
    mov man_y,eax
    ;man_flag = back_man_flag
    mov ax, back_man_flag
    mov man_flag, ax
    ;box_x = bx
    mov eax, bx_8
    mov box_x, eax
    ;steps--
    sub steps, 1
    ;draw_level_and_steps()
    call draw_level_and_steps
    ;back_available = 0
    mov back_available, 0
go_back_before_end:
    ;return 1
    mov eax, 1
go_back_end:
    mov esp, ebp
    pop ebp
    ret
go_back_fail:
    ;return 0
    mov eax, 0
    jmp go_back_end
go_back endp

go_esc proc near 

;利用eax传参
ps_7 equ word ptr [ebp - 2]
fp_7 equ word ptr [ebp - 4]
n_7 equ dword ptr [ebp - 8]
x_7 equ dword ptr [ebp - 12]
y_7 equ dword ptr [ebp - 16]

go_esc_begin:
    push ebp
    mov ebp, esp
    sub esp, 16
    ;/* save info to file */
    ;fp = fopen("box.sav", "wb");
    mov ah, 3Ch
    mov dx, offset filename4
    ;ds:dx->文件名地址
    mov cx, 0
    int 21h
    mov fp_7, ax
    ;if(fp == NULL)
    cmp fp_7, 0
    jne go_esc_offset1
    ;  return -1;
    mov eax, -1
    jmp go_esc_end
go_esc_offset1:
    ;ps = malloc(sizeof(SAVE));
    mov ah, 48h
    mov bx, sizeof_SAVE
    add bx, 0Fh
    shr bx, 4
    int 21h
    mov ps_7, ax
    ;if(ps == NULL)
    cmp ps_7, 0
    jne go_esc_offset2
    ;  return -1;
    mov eax, -1
    jmp go_esc_end
go_esc_offset2:
    mov dx, ps_7
    mov es, dx
    ;ps->magic[0] = 'B';
    mov es:[0], byte ptr 'B'
    ;ps->magic[1] = 'W';
    mov es:[1], byte ptr 'W'
    ;ps->level = level;
    mov eax, level
    mov es:[0]._level, eax
    ;ps->steps = steps;
    mov eax, steps
    mov es:[0]._steps, eax
    ;ps->man_x = man_x;
    mov eax, man_x
    mov es:[0]._man_x, eax
    ;ps->man_y = man_y;
    mov eax, man_y
    mov es:[0]._man_y, eax
    ;ps->man_flag = man_flag;
    mov ax, man_flag
    mov es:[0]._man_flag, ax
    ;for(y=1; y<=map_rows[blk_size_level]; y++)
    ;  for(x=1; x<=map_columns[blk_size_level]; x++)
    mov y_7, 1
    jmp go_esc_judge1
go_esc_loop1:
    mov x_7, 1
    jmp go_esc_judge2
go_esc_loop2:
    ;    ps->flag[y][x] = pmap->flag[y][x][level_in_map];
    push level_in_map
    push x_7
    push y_7
    call find_pmap_flag
    add sp, 12
    mov cx, ax
    mov dx, ps_7
    mov es, dx
    mov eax, y_7
    mov bx, 29h
    mul bx
    add eax, x_7
    mov si, ax
    shl si, 1; si = si * 2
    mov es:[si]._flag, cx; ps->flag[y][x]
    ;     /* save map info */
go_esc_pass2:
    add x_7, 1
go_esc_judge2:
    call find_map_columns_number
    cmp x_7, eax
    jbe go_esc_loop2
go_esc_pass1:
    add y_7, 1
go_esc_judge1:
    call find_map_rows_number
    cmp y_7, eax
    jbe go_esc_loop1
go_esc_part2:
    ;fwrite(ps, 1, sizeof(SAVE), fp);
    mov ax, ds
    mov es, ax
    mov ax, 4000h
    mov bx, fp_7
    mov ds, ps_7
    mov dx, 0
    mov cx, sizeof_SAVE
    int 21h
    mov ax, es
    mov ds, ax
    ;fclose(fp);
    mov ah, 3Eh
    mov bx, fp_7
    int 21h
    ;free(ps);
    mov ax, ps_7
    call freebuf
    ;return -1; /* always return -1 to stop playing */
    mov eax, -1   
go_esc_end:
    mov esp, ebp
    pop ebp   
    ret
go_esc endp

do_walk_or_push proc near
; 用栈传参
; 返回值 eax
push_flag EQU word ptr [ebp + 8]
walk_flag EQU word ptr [ebp + 6]

do_walk_or_push_start:
    push ebp
    mov ebp, esp

    ;nflag = pmap->flag[ny][nx][level_in_map]
    push level_in_map
    push nx
    push ny
    call find_pmap_flag
    add sp, 12
    mov nflag, ax
    ;fflag = pmap->flag[fy][fx][level_in_map];
    push level_in_map
    push fx
    push fy
    call find_pmap_flag
    add sp, 12
    mov fflag, ax   
    ; if(nflag == ROCK || nflag == BRICK)
    cmp nflag, ROCK
    je do_walk_or_push_fail
    cmp nflag, BRICK
    je do_walk_or_push_fail
    ;opx = (ox-1) * obj_width[blk_size_level]; /* 当前(x,y)转化成像素坐标 */
    push ox
    call x_subone_width
    add sp, 4
    mov opx, eax
    ;opy = (oy-1) * obj_height[blk_size_level];
    push oy
    call x_subone_height
    add sp, 4
    mov opy, eax
    ;npx = (nx-1) * obj_width[blk_size_level]; /* 前面一格(x,y)转化成像素坐标 */
    push nx
    call x_subone_width
    add sp, 4
    mov npx, eax
    ;npy = (ny-1) * obj_height[blk_size_level];
    push ny
    call x_subone_height
    add sp, 4
    mov npy, eax
    ;fpx = (fx-1) * obj_width[blk_size_level]; /* 前面二格(x,y)转化成像素坐标 */
    push fx
    call x_subone_width
    add sp, 4
    mov fpx, eax
    ;fpy = (fy-1) * obj_height[blk_size_level];
    push fy
    call x_subone_height
    add sp, 4
    mov fpy, eax
    ; if(nflag == FLOOR || nflag == BALL)
    cmp nflag, FLOOR
    je do_walk_or_push_offset1
    cmp nflag, BALL
    je do_walk_or_push_offset1
    ;if(nflag == BOX || nflag == BOB) /* push */
    cmp nflag, BOX
    je do_walk_or_push_offset2
    cmp nflag, BOB
    je do_walk_or_push_offset2
    ;return
    jmp do_walk_or_push_end
do_walk_or_push_offset1:
    ;put_obj(blk_buf, opx, opy); /* hide man */
    mov eax, opy
    push eax
    mov eax, opx
    push eax
    mov ax, blk_buf
    push ax
    call put_obj
    add sp, 10
    ;----------------------------------------------
    ;get_obj(blk_buf, npx, npy, obj_width[blk_size_level], obj_height[blk_size_level])
    mov eax, ny
    mov ebx, nx
    call get_obj
    ;put_obj(man_blk[blk_size_level][walk_flag].blk_ptr, npx, npy); /* [%] */
    mov eax, npy
    push eax
    mov eax, npx
    push eax
    mov ax, walk_flag
    push ax
    call find_man_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;back_available = 0;
    mov back_available, 0
    ;man_flag = walk_flag;
    mov ax, walk_flag
    mov man_flag, ax
    ;man_x = nx;
    mov eax, nx
    mov man_x, eax
    ;man_y = ny;
    mov eax, ny
    mov man_y, eax
    ;steps++
    add steps, 1
    ;draw_level_and_steps();
    call draw_level_and_steps
    mov eax, 1; return 1
    jmp do_walk_or_push_end
do_walk_or_push_offset2:
    ;if(fflag != FLOOR && fflag != BALL)
    cmp fflag, FLOOR
    je do_walk_or_push_offset2_1
    cmp fflag, BALL
    je do_walk_or_push_offset2_1
    ;return 0
    jmp do_walk_or_push_fail
do_walk_or_push_offset2_1:
    ;put_obj(blk_buf, opx, opy); /* hide man */
    push opy
    push opx 
    push blk_buf
    call put_obj
    add sp, 10
    ;if(nflag == BOB)
    cmp nflag, BOB
    je do_walk_or_push_offset3
    ;put_obj(obj_blk[blk_size_level][FLOOR].blk_ptr, npx, npy); /* recover floor */
    push npy
    push npx
    mov ax, FLOOR
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;pmap->flag[ny][nx][level_in_map] = FLOOR;
    mov ax, FLOOR
    push ax
    mov eax, level_in_map
    push eax
    mov eax, nx
    push eax
    mov eax, ny
    push eax
    call assign_pmap_flag
    add sp, 14
    jmp do_walk_or_push_continue1 
do_walk_or_push_offset3:
    ;put_obj(obj_blk[blk_size_level][BALL].blk_ptr, npx, npy); /* recover ball */
    mov eax, npy
    push eax
    mov eax, npx
    push eax
    mov ax, BALL
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;pmap->flag[ny][nx][level_in_map] = BALL;
    mov ax, BALL
    push ax
    mov eax, level_in_map
    push eax
    mov eax, nx
    push eax
    mov eax, ny
    push eax
    call assign_pmap_flag
    add sp, 14
    ;bob_count--;
    sub bob_count, 1
do_walk_or_push_continue1:
    ;get_obj(blk_buf, npx, npy, obj_width[blk_size_level], obj_height[blk_size_level]);
    mov eax, ny
    mov ebx, nx
    call get_obj
    ;if(fflag == BALL)
    cmp fflag, BALL
    je do_walk_or_push_offset4
;put_obj(obj_blk[blk_size_level][BOX].blk_ptr, fpx, fpy); /* draw box */
    mov eax, fpy
    push eax
    mov eax, fpx
    push eax
    mov ax, BOX
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
;pmap->flag[fy][fx][level_in_map] = BOX;      
    mov ax, BOX
    push ax
    push level_in_map
    push fx
    push fy
    call assign_pmap_flag
    add sp, 14
    jmp do_walk_or_push_continue2
do_walk_or_push_offset4:
;put_obj(obj_blk[blk_size_level][BOB].blk_ptr, fpx, fpy); /* draw bob */
    mov eax, fpy
    push eax
    mov eax, fpx
    push eax
    mov ax, BOB
    push ax
    call find_obj_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
;pmap->flag[fy][fx][level_in_map] = BOB;
    mov ax, BOB
    push ax
    mov eax, level_in_map
    push eax
    mov eax, fx
    push eax
    mov eax, fy
    push eax
    call assign_pmap_flag
    add sp, 14
;bob_count++
    add bob_count, 1
do_walk_or_push_continue2:
;put_obj(man_blk[blk_size_level][push_flag].blk_ptr, npx, npy); /* draw man */
    mov eax, npy
    push eax
    mov eax, npx
    push eax
    mov ax, push_flag
    push ax
    call find_man_blk_ptr
    add sp, 2
    push ax
    call put_obj
    add sp, 10
    ;back_man_flag = man_flag;
    mov ax, man_flag
    mov back_man_flag, ax
    ;  back_man_x = ox;
    mov eax, ox
    mov back_man_x, eax
    ;  back_man_y = oy;
    mov eax, oy
    mov back_man_y, eax
    ;  back_box_x = nx;
    mov eax, nx
    mov back_box_x, eax
    ;  back_box_y = ny;
    mov eax, ny
    mov back_box_y, eax
    ;  man_flag = push_flag;
    mov ax, push_flag
    mov man_flag, ax
    ;  man_x = nx;
    mov eax, nx
    mov man_x, eax
    ;  man_y = ny;
    mov eax, ny
    mov man_y, eax
    ;  box_x = fx;
    mov eax, fx
    mov box_x, eax
    ;  box_y = fy;
    mov eax, fy
    mov box_y, eax
    ;  back_available = 1;
    mov back_available, 1
    ;  steps++;
    add steps, 1
    ;  draw_level_and_steps();
    call draw_level_and_steps
    ;  if(bob_count == ball_count)
    mov ax, bob_count
    cmp ball_count, ax
    je do_walk_or_push_2
      ;   return 2; /* level done */
      ;else
      ;   return 1; /* success */
    mov eax, 1; return 1
do_walk_or_push_end:
    mov esp, ebp
    pop ebp
    ret
do_walk_or_push_2:
    mov eax, 2; return 2
    jmp do_walk_or_push_end
do_walk_or_push_fail:
    mov eax, 0; return 0
    jmp do_walk_or_push_end
do_walk_or_push endp

draw_level_and_steps proc near
; 无传参
; 无返回值
i_9 EQU dword ptr [ebp - 4]
n_9 EQU dword ptr [ebp - 8]
d_9 EQU dword ptr [ebp - 12]
digit_width EQU dword ptr [ebp - 16]

draw_level_and_steps_start:
    push ebp
    mov ebp, esp
    sub esp, 16

    ; digit_width = 0x0C
    mov digit_width, 0Ch
    ;sprintf(str_level, "%03d", level)
    mov edx, 0
    mov eax, level
    mov ebx, 10
    div ebx
    mov str_level[2], '0'
    add str_level[2], dl
    mov edx, 0
    mov ebx, 10
    div ebx
    mov str_level[1], '0'
    add str_level[1], dl
    mov edx, 0
    mov ebx, 10
    div ebx
    mov str_level[0], '0'
    add str_level[0], dl
    ;sprintf(str_steps, "%04d", steps)
    mov edx, 0
    mov eax, steps
    mov ebx, 10
    div ebx
    mov str_steps[3], '0'
    add str_steps[3], dl
    mov edx, 0
    mov ebx, 10
    div ebx 
    mov str_steps[2], '0'
    add str_steps[2], dl
    mov edx, 0
    mov ebx, 10
    div ebx 
    mov str_steps[1], '0'
    add str_steps[1], dl
    mov edx, 0
    mov ebx, 10
    div ebx 
    mov str_steps[0], '0'
    add str_steps[0], dl
    ;n = strlen(str_level); /* n = 3 */
    mov n_9, 3

    mov i_9, 0
draw_level_and_steps_loop1:
    ;d = str_level[i] - '0'
    mov eax, 0
    mov ebx, i_9
    mov al, str_level[bx]
    sub al, '0'
    mov d_9, eax
    ;put_obj(txt_blk[d].blk_ptr, bar_px+(8+i)*digit_width, bar_py+4)
    mov eax, bar_py
    add eax, 4
    push eax
    mov edx, 0
    mov eax, i_9
    add eax, 8
    mov ebx, digit_width
    mul ebx
    add eax, bar_px
    push eax
    mov eax, d_9
    call load_txt_ptr
    push ax
    call put_obj
    add sp, 10
draw_level_and_steps_pass1:
    add i_9, 1
draw_level_and_steps_judge1:
    mov eax, n_9
    cmp i_9, eax
    jb draw_level_and_steps_loop1
    ;n = strlen(str_steps); /* n = 4 */
    mov n_9, 4

    mov i_9, 0
draw_level_and_steps_loop2:
    ;d = str_steps[i] - '0'
    mov eax, 0
    mov ebx, i_9
    mov al, str_steps[bx]
    sub al, '0'
    mov d_9, eax
    ;put_obj(txt_blk[d].blk_ptr, bar_px+6+(19+i)*digit_width, bar_py+4)
    mov eax, bar_py
    add eax, 4
    push eax
    mov eax, i_9
    add eax, 19
    mov ebx, digit_width
    mul ebx
    add eax, bar_px
    add eax, 6
    push eax
    mov eax, d_9
    call load_txt_ptr
    push ax
    call put_obj
    add sp, 10
draw_level_and_steps_pass2:
    add i_9, 1
draw_level_and_steps_judge2:
    mov eax, n_9
    cmp i_9, eax
    jb draw_level_and_steps_loop2   
draw_level_and_steps_end:
    mov esp, ebp
    pop ebp
    ret
draw_level_and_steps endp

freebuf proc near
;释放内存，ax传入段地址
    mov es, ax
    mov ah, 49h
    int 21h
    ret
freebuf endp

get_obj proc near
;eax = ny, ebx = nx
    ;pmap->flag[y][x][level_in_map]
    push level_in_map
    push ebx
    push eax
    call find_pmap_flag
    add sp, 12
    ;free(blk_buf)
    mov bx, ax; flag = flag
    mov ax, blk_buf
    call freebuf
    ;obj_blk[blk_size_level][flag].ptr
    mov ax, blk_size_level
    call load_obj_ptr
    mov blk_buf, ax
    ret
get_obj endp

code ends

stk segment stack use16
    db 200h dup(0)
end_flag label byte
stk ends

end main