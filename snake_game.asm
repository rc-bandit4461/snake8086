
org  100h
.data
; 
; les coordonnees du serpent( de la tete a la queue)
; (X,Y) = (lower byte,higher byte)
snake dw 10Dh,10Ch,10Bh,10Ah, 150 dup(?)   ;(X0,Y0),(X1,Y1)...  ; reservation de memoire
s_size  db     4,0       ; longueure du snake                             ; pour ne pas ecraser les autres
                                                                          ; variables
tail    dw      ?       ;; coordonnees de la queue precedente  (lower byte X,higher byte Y)

; constantes de directions
;  (bios key codes):
left    equ     4bh
right   equ     4dh
up      equ     48h
down    equ     50h 

; direction courante du snake
cur_dir db      right
; ancienne direction du snake
old_dir db      right
; coordonnees du Meal
mealX  db  ?
mealY  db  ?

; score
score db '0','0','0','0','$'

; message de debut
msgstart db 5 dup(0ah),15 dup(20h)
 db             "  _______ _             _____             _         ", 0dh,0ah
 db 15 dup(20h)," |__   __| |           / ____|           | |        ", 0dh,0ah       
 db 15 dup(20h),"    | |  | |__   ___  | (___  _ __   __ _| | _____  ", 0dh,0ah
 db 15 dup(20h),"    | |  | '_ \ / _ \  \___ \| '_ \ / _` | |/ / _ \ ", 0dh,0ah
 db 15 dup(20h),"    | |  | | | |  __/  ____) | | | | (_| |   <  __/ ", 0dh,0ah
 db 15 dup(20h),"   _|_|_ |_| |_|\___| |_____/|_| |_|\__,_|_|\_\___| ", 0dh,0ah
 db 15 dup(20h),"  / ____|                    | |                    ", 0dh,0ah
 db 15 dup(20h)," | |  __  __ _ _ __ ___   ___| |                    ", 0dh,0ah
 db 15 dup(20h)," | | |_ |/ _` | '_ ` _ \ / _ \ |                    ", 0dh,0ah
 db 15 dup(20h)," | |__| | (_| | | | | | |  __/_|                    ", 0dh,0ah
 db 15 dup(20h),"  \_____|\__,_|_| |_| |_|\___(_)                    ", 0dh,0ah,0ah
 db 25 dup(20h),"     Press Enter to start.                            $"    

; message de fin
msgover db  5 dup(0ah),15 dup(20h)
 db              "  ___   __   _  _  ____     __   _  _  ____  ____ ", 0dh,0ah 
 db  15 dup(20h)," / __) / _\ ( \/ )(  __)   /  \ / )( \(  __)(  _ \", 0dh,0ah 
 db  15 dup(20h),"( (_ \/    \/ \/ \ ) _)   (  O )\ \/ / ) _)  )   /", 0dh,0ah 
 db  15 dup(20h)," \___/\_/\_/\_)(_/(____)   \__/  \__/ (____)(__\_)", 0dh,0ah,0ah,0ah                                                  
 db  30 dup(20h),"   Your score is $", 0dh,0ah
                                                    
; ------ code section ------

.code  
    mov dx, offset msgstart     ;;
    mov ah, 9 
    int 21h
    mov ax, 40h                   
    mov es, ax 

 ; attendre la saisie de la touche entree
wait_for_enter:
    mov ah, 00h 
    int 16h
    cmp al,0dh      
    jne wait_for_enter          
                                ;;                               
    mov al, 1 ; basculer vers la page 1 
    mov ah, 05h
    int 10h
   call randomizeMeal 

;;----------------

game_loop: 

     ; === afficher la nouvelle tete
    call shownewhead
     ; ====== verification si le serpent va mourrir           ;;
    mov dx,snake[0]
    mov si,w.s_size  ;si recoit s_size*2-2
    add si,w.s_size 
    sub si,2
    mov cx,w.s_size
    sub cx,4
    jz no_death
deathloop: 
                   
    cmp dx,snake[si]  ;; tete coincide avec une partie du serpent ?
    je game_over
    sub si,2
    dec cx
    jnz deathloop
no_death:                                          
;    sauvegarde de la queue... pour l'effacer plus tard.
    mov si,w.s_size   ; si recoit (s_size-1)*2
    add si,w.s_size
    sub si,2
    mov ax, snake[si]  
    mov tail, ax     

    call move_snake           ;;

; ===     coordonnees de la tete  == coordonnees de Meal ?

    mov dx,snake[0]
    mov al,mealX
    mov ah,mealY
    cmp ax,dx
    jne hide_old_tail
    mov al,s_size
    inc al
    mov s_size,al
    mov ax,tail
    mov bh,0
    mov bl,s_size
    add bl,s_size
    sub bl,2
    mov snake[bx],ax
    call scoreplus
    call randomizeMeal
    jmp no_hide_old_tail
     ;; elargir snake et afficher la dernier colonne


hide_old_tail:
;===========================================
; === hide old tail:
mov     dx, tail

; deplacer le curseur 
mov     ah, 02h
int     10h

; print ' ' at the location:   affichage de ' ' dans les coordonnes de tail
mov     al, ' '
mov     ah, 09h
mov     bl, 0fh ; attribute. le char ' ' surface dialo 5awya lower 4bits ma3andhomch
mov     cx, 1   ; single char.
int     10h


no_hide_old_tail:

; === check for player commands:
mov     ah, 01h     ; ya t'il quelque chose dans la memoire tampon du clavier?
int     16h
jz      no_key  ;;

mov     ah, 00h     ;si oui, la recevoir 
int     16h         ;
mov cur_dir,ah
 
no_key:

jmp     game_loop

game_over:
xor dx,dx              ; dx = 0
mov ah, 02h        ; deplacer le curseur vers (0,0)
int 10h
mov dx,offset msgover  ; affichage du message de fin
mov ah,09h
int 21h
mov dx,offset score    ; affichage du score
mov ah,09h
int 21h
ret

; ------ fonctions ------

move_snake proc

;  
  ; pointer di vers la queue
  
  mov   di,w.s_size     ;; di recoit (s_size-1)*2
  add di,w.s_size
  sub di,2
  ; deplacement du corps (les coordonnees)
  ; de la queuve vers
  mov cx,w.s_size
  dec cx
  
move_array:
  mov   ax, snake[di-2]   
  mov   snake[di], ax         ;; 
  sub   di, 2                 ;; 
  loop  move_array            ;; 

getdir:
cmp     cur_dir, left
  je    move_left
cmp     cur_dir, right
  je    move_right
cmp     cur_dir, up
  je    move_up
cmp     cur_dir, down
  je    move_down
getolddir:
        mov al,old_dir
        mov cur_dir,al
jmp     getdir       ; new dir =  old dir

move_left:
  cmp old_dir,right
  je getolddir
  mov   al, b.snake[0]
  dec   al              ;X--
  mov   b.snake[0], al  ;
  cmp   al, -1
  jne   stop_move       
  mov   al, es:[4ah]    ;es:[4ah] fiha nombre de colonnes f lecran
  dec   al              ;; numero de colonne (0 7tal es[4ah]-1)
  mov   b.snake[0], al  ; 
  jmp   stop_move

move_right:
  cmp old_dir,left
  je getolddir
  mov   al, b.snake[0]    ; meme principe
  inc   al                ; X++;
  mov   b.snake[0], al    ;
  cmp   al, es:[4ah]      ; X < numero dernier colonne ?
  jb    stop_move         ;oui:continuer mvt
  mov   b.snake[0], 0     ; retourner a gauche (x(head) = 0)
  jmp   stop_move         ;continuer mvt

move_up:
  cmp old_dir,down
  je getolddir            ;meme principe
  mov   al, b.snake[1]    ;Y-- 
  dec   al                ;
  mov   b.snake[1], al    ;
  cmp   al, -1
  jne   stop_move
  mov   al, es:[84h]      ;
  mov   b.snake[1], al    ;
  jmp   stop_move

move_down:
  cmp old_dir,up
  je getolddir
  mov   al, b.snake[1]
  inc   al                ;
  mov   b.snake[1], al    ;
  cmp   al, es:[84h]      ; 
  jbe   stop_move         ;
  mov   b.snake[1], 0     ;
  jmp   stop_move

stop_move:                ; old_dir <-- cur_dir
  mov al,cur_dir
  mov old_dir,al
  ret
move_snake endp

;;===== procedure de generation de Meal
 
randomizeMeal proc near
reRandomize:
    mov ah, 00h   ; ; interruption pour recevoir le temps du systeme       
    int 1ah       ; CX:DX recoit le nombre de cycle depluis la nuit    
    mov ax, dx
    xor dx, dx
    mov cx,10     ; 25 est la largeure de l'ecran
    div cx       ; equivalente a rand()%25   DX va recevoir le reste de la division de DX:AX par CX
    mov mealY,dl

   mov ah, 00h           
   int 1ah        ;    
   mov ax, dx
   xor dx, dx
   mov cx,10      ; 80 est la longueure de l'ecran
   div cx        ; equivalente a rand()%80  DX va recevoir le reste de la division de DX:AX par CX

    mov mealX,dl
    mov dh,mealY
    ; si le meal a pris des coordonnes d'une partie du serpent
    ;xor cx,cx
    mov cx,w.s_size
    xor bx,bx
no_overwrite_snake:
    cmp dx,snake[bx]
    je reRandomize
    add bx,2
    dec cx
    jnz no_overwrite_snake
    ;--- affichage de meal    
    mov ah, 02h  ; deplacer le curseur dans  at (X,Y)=(dl,dh)
    mov bh,01h           
    int 10h
    mov al, 0e4h           
    mov     bl, 0b9h ; attribute; lower 4bits : couleur du char; higher 4 bits: couleur background du char
   ;mov     bh,01h  ;; page 1
    mov     cx, 1   
    mov     ah, 09h 
    int     10h
    ret
randomizeMeal endp

;====== procedure d'incrementation de score

scoreplus proc
        
    mov al,score[3]     ;; incrementer le premier chiffre
    inc al
    cmp al,'9'         ;; premier chiffre a depasse '9' ?
    jg inc_second
    mov score[3],al
    ret
    
inc_second:
    mov score[3],'0'    ;; rendre le premier chiffre a '0'
    mov al,score[2]     ;; incrementer le deuxieme chiffre
    inc al
    cmp al,'9'          ;; deuxieme chiffre a depasse '9' ?
    jg inc_third
    mov score[2],al
    ret
    
inc_third:
    mov score[2],'0'    ;; rendre le deuxieme chiffre a '0'
    mov al,score[1]     ;; incrementer le troisieme chiffre
    inc al
    cmp al,'9'          ;; troisieme chiffre a depasse '9' ?
    jg inc_fourth
    mov score[1],al
    ret
    
inc_fourth:
    mov score[1],'0'    ;; rendre le troisieme chiffre a '0'
    mov al,score[0]     ;; incrementer le quatrieme chiffre
    inc al              ;; 
    mov score[0],al
    ret
     
scoreplus endp
;; ==== procedure d'affichage de la nouvelle tete 

shownewhead proc
    mov     dx, snake[0]        
    mov     ah, 02h             
    int     10h
    mov     al, 'k'     ; 'k' pour pouvoir compter la longueur       
    mov     ah, 09h 
    mov     bl, 0f5h 
    mov     bh,01h  
    mov     cx, 1   
    int     10h
    ret
shownewhead endp

.exit
end

