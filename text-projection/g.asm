data1 segment

zoom db ?

; zmienne używane przy wypisywaniu, wypisueje sie zawsze punkt (x, y) o kolorze k 
x dw 0
y dw 0
k db 13

; wypełnienie pamięci grafiki 
horizontal_fullfilment dw 0
vertical_fullfilment dw 0

; bufor na tekst do wyświetlenia oraz jego długość
text_buf_len db ?
text_buf db 255 dup('$')

; zmienne dotyczące liter
letter_buf db 100 dup('$')     ; tutaj będzie przetrzymywana bitmapa
letter_file_name db "bitmaps\", 0, 0, 0, 0, 0, 0, 0, 0        
first_digit db ?   ; kod ASCII cyfry setek kodu ASCII danego znaku 
second_digit db ?  ; kod ASCII cyfry dziesiątek kodu ASCII danego znaku
third_digit db ?   ; kod ASCII cyfry jedności kodu ASCII danego znaku
hundred db 100
ten db 10

; wiadomości przy błędach
error_open db "blad otwierania", 10, 13, '$'
error_read db "blad czytania", 10, 13, '$'

data1 ends

code1 segment

start1:
;--------------------------------------------------------------------------------
	call stack_init ; inicjalizacja stosu
	
	call parse_args ; parsuje dane z linii komend oraz zapisuej je w
	; text_buf, text_buf_len oraz zoom
	
	call enter_graphic_mode ; wejście w tryb graficzny 320x200 w 256 kolorach
	
	call print_text_buf ; wpisanie do pamięci ekranu całej zawartości text_buf
	
	call wait_for_key ; czekanie na klawisz
	
	call leave_graphic_mode ; opuszczenie trybu graficznego
	
	call end_program ; wyjście z programu
;--------------------------------------------------------------------------------






; procedury
stack_init:
	mov ax,seg top1  
    mov ss,ax
    mov sp,offset top1
	ret
	
	
	

parse_args:	
	xor cx, cx 

	mov si, 82h  ; poczatk parametrów
	mov cl, byte ptr ds:[80h]  ; liczba znaków
	
	mov bx, seg zoom
	mov es, bx
	mov di, offset zoom
	
	mov al, byte ptr ds:[si] ; wartość zoom
	mov byte ptr es:[di], al
	sub byte ptr es:[di], 48d ; przesuwam żeby mieć wartość cyfry a nie jej kod ASCII
	
	dec cl
	inc si ; skopiowaliśmy jeden znak więc idziemy dalej
	
	dec cl
	inc si ; pomijamy spacje
	
	dec cl ; pomijamy znak carriage return
	
	mov di, offset text_buf_len ; kopiuje długość tesktu
	mov byte ptr es:[di], cl
	
	mov di, offset text_buf
	
	cld        
	rep movsb ; kopiuje es:[di] <= ds:[si]  
	
	ret
	
	
	
	
enter_graphic_mode:	
	mov ah, 00 
	mov al, 13h
	int 10h
	ret
	



print_text_buf:
	mov ax, seg text_buf
	mov ds, ax
	mov si, offset text_buf

	xor cx, cx
	mov cl, byte ptr ds:[text_buf_len]  ; będę przechodził w pętli po całym buforze
	
	text_buf_loop:
		push cx
		push ds
		push si
		
		xor ax, ax
		mov al, 8
		mul byte ptr ds:[zoom]
		mov cx, 200
		sub cx, ax 
		cmp word ptr ds:[vertical_fullfilment], cx  
		
		jle not_exit          ; na początku sprawdzam czy nie skońćzył się ekran w pionie
		; jeśli tak to kończe działanie programu
		
		call wait_for_key
		call leave_graphic_mode
		call end_program
		
		not_exit:
		call to_string           ; kod pierwszego znaku bufora zamieniam na 3 znaki: np. 123 -> '1', '2', 3'
		; oraz zapisuje w first_digit, second_digit, third_digit
		call create_letter_file_name ; na podstawie poprzednich obliczeń tworze nazwe pliku i zapisuje wait_for_key
		; letter_file_name: np. '1', '2', '3' => "bitmaps\123.txt", 0
		call open_letter_file ; otwieram plik odpowiadajacy danej literze i zapisuje bitmape do letter_buf
		call print_letter ; zapisuje do pamięci ekranu literę oraz przesuwam x i 
		
		xor ax, ax
		mov al, 8
		mul byte ptr ds:[zoom]
		add word ptr ds:[horizontal_fullfilment], ax  ; dodaje do wypełnienia horyzontalnego tyle pikseli
		; ile przeszliśmy w prawo czyli zoom*8
		
		mov cx, 311 ; takie ograniczenie a nie 320 bo na dosboxie coś dziwnie wyglądało
		sub cx, ax
		cmp word ptr ds:[horizontal_fullfilment], cx  ; sprawdzam, czy kolejny znak się jeszcze zmieści
		
		jle not_return_carriage ; jeśli nie to przesuwam "kursor" do kolejnej linji
		
		mov word ptr ds:[horizontal_fullfilment], 0 ; zerowanie wypełnienia w poziomie
		
		mov word ptr ds:[x], 0 ; zerowanie wspolrzednej x
		
		xor ax, ax
		mov al, 8
		mul  byte ptr ds:[zoom]
		add word ptr ds:[vertical_fullfilment], ax ; dodaje do wypełnienia w pionie zoom*8
		add word ptr ds:[y], ax ; dodaje do y zoom*8
		
		not_return_carriage:
		pop si
		pop ds
		pop cx
		inc si
		loop text_buf_loop
	
	ret
	
	
	

wait_for_key:
	xor ax, ax
	int 16h
	ret
	
	
	
	
leave_graphic_mode:
	mov al, 3h     
	mov ah, 0
	int 10h
	ret
	
	
	
	
end_program:
	mov al, 0
    mov ah, 4ch   
    int 21h 
	ret
	
	
	
	
to_string:
	xor ax, ax
	mov al, byte ptr ds:[si]
	div byte ptr ds:[hundred]
	add al, 48
	mov byte ptr ds:[first_digit], al  ; zapisuje kod ASCII pierwszej cyfry w first_digit
	
	mov al, ah
	xor ah, ah
	div byte ptr ds:[ten]
	add al, 48
	mov byte ptr ds:[second_digit], al ; zapisuje kod ASCII drugiej cyfry w first_digit
	
	add ah, 48
	mov byte ptr ds:[third_digit], ah ; zapisuje kod ASCII trzeciej cyfry w third_digit
	
	; Nie muszę się martwić o zero w drugiej i trzeciej cyfrze, bo
	; liczby są z zakresu 32-126
	
	ret
	
	
	
	
create_letter_file_name:
	mov di, offset letter_file_name
	add di, 8                       ; przesuwam się tak aby pisac po nazwie katalogu
	
	cmp byte ptr ds:[first_digit], 48
	je skip_first_zero ; jeśli pierwsza cyfra jest zero, to ją pomijam
	
	mov al, byte ptr ds:[first_digit] ; wpisuje pierwsza cyfre do nazwy pliku
	mov byte ptr ds:[di], al
	inc di
	
	skip_first_zero:
	mov al, byte ptr ds:[second_digit] ; wpisuje druga cyfre do nazwy pliku
	mov byte ptr ds:[di], al  
	inc di
	
	mov al, byte ptr ds:[third_digit] ; wpisuje trzecia cyfre do nazwy pliku
	mov byte ptr ds:[di], al
	
	; dopisuje rozszerzenie pliku
	inc di
	mov byte ptr ds:[di], '.'
	inc di
	mov byte ptr ds:[di], 't'
	inc di
	mov byte ptr ds:[di], 'x'
	inc di
	mov byte ptr ds:[di], 't'
	inc di
	mov byte ptr ds:[di], 0
	
	ret	

	
	
	
open_letter_file:
	; otwieram plik z odpowiednią literą
	mov ax, seg letter_file_name
	mov ds, ax
	mov dx, offset letter_file_name  
	mov ax, 3d02h 
	int 21h 
	jc open_error
	
	; czytam z pliku bitmapę
	mov bx, ax
	mov ax, seg letter_buf
	mov ds, ax
	mov dx, offset letter_buf
	mov cx, 100
	mov ah, 3fh
	mov al, 0
	int 21h
	jc read_error
	
	; zamykam plik
	mov ah, 3eh
	int 21h
	
	ret
	
	read_error:
	call leave_graphic_mode
	mov dx, offset error_read
	mov ax, seg error_read ; obsługa błędu (flaga CF przy czytaniu)
	call print
	call end_program
	
	open_error:
	call leave_graphic_mode
	mov dx, offset error_open
	mov ax, seg error_open    ; obsługa błędu (flaga CF przy otwieraniu)
	call print
	call end_program




print_letter:
	mov ax, seg letter_buf
	mov ds, ax
	mov si, offset letter_buf
	
	xor cx, cx
	mov cl, 8   ; bitmapa jest 8x8 więc przechodzę po 8 razy w każdej pętli
	
	row_loop:
		push cx
		push ds:[x]
		
		mov cl, 8
		col_loop:	
			cmp byte ptr ds:[si], '1' 
			jne not_print ; jeśli w bitmapie natrafię na 1 to wypisuje punkt
			
			push cx
			push ds
			push si
			call print_point ; wypisanie punktu o rozmiarze (zoom) x (zoom)
			pop si
			pop ds
			pop cx
			
			not_print:
			inc si
			xor ax, ax
			mov al, byte ptr ds:[zoom]
			add word ptr ds:[x], ax ; przesuwam x o zoom w prawo, bo tyle wypełniłem pikseli
			
			loop col_loop
			
		inc si
		xor ax, ax
		mov al, byte ptr ds:[zoom]
		add word ptr ds:[y], ax ; idę do kolejnego wiersza
		
		pop ds:[x]
		pop cx
		loop row_loop
	
	xor ax, ax
	mov al, 8
	mul byte ptr ds:[zoom]
	sub word ptr ds:[y], ax  ; wracam w ten sposób, aby znowu móc zacząć pisać od lewego górnego rogu
	
	xor ax, ax
	mov al, 7
	mul byte ptr ds:[zoom]
	add word ptr ds:[x], ax ; wracam w ten sposób, aby znowu móc zacząć pisać od lewego górnego rogu
	
	ret
	
	


print_point:
	; będę wypisywał punkt o rozmiarach (zoom) x (zoom)
	push word ptr ds:[x]
	push word ptr ds:[y]  ; wrzucam na stos, ponieważ odpowiednie przesunięcia wykonuje
	; w funkjic wyżej
	
	xor cx, cx
	mov cl, byte ptr ds:[zoom] ; dwie pętle po współrzędnych każda po zoom iteracjiy=
	x_loop:	
		push cx
		push word ptr ds:[y]
		
		mov cl, byte ptr ds:[zoom]
		y_loop:
			call print_pixel  ; wypisuje pikse;
			
			inc byte ptr ds:[y]
			loop y_loop
		
		
		inc byte ptr ds:[x]
		pop word ptr ds:[y]  ; resetuje y
		pop cx
		loop x_loop
	
	pop word ptr ds:[y]
	pop word ptr ds:[x]
	ret
	



print_pixel:
	; zapisuje pod odpowiednim adresem wartość k,
	; czyli wypełniam piksel o pozyji (x, y) kolorem k
	mov ax, seg x
	mov ds, ax
	mov ax, 0a000h
	mov es, ax  
	mov ax, word ptr ds:[y]
	mov di, 320
	mul di
	add ax, word ptr ds:[x]
	mov di, ax
	mov al, byte ptr ds:[k]
	mov byte ptr es:[di], al ; es:di pamięc ekranu karty
	ret




print:
	mov ds, ax
	mov ah, 9 ; wypisze ds:dx
	int 21h
	ret
	


	
code1 ends

stos1 segment stack

	dw 100 dup(?)
top1 dw ?

stos1 ends

end start1