data1 segment

; bufory oraz ich stopien wypelnienia
key db 20 dup(?)
key_len db ?
file_buf db 255 dup('$')
file_buf_len db ?

; nazwy plików oraz ich handlery
in_file_name db 20 dup(0)
out_file_name db 20 dup(0)           
in_file_handler dw ?
out_file_handler dw ?

;wiadomości przy błedach
error_open db "blad otwierania", 10, 13, '$'
error_read db "blad czytania", 10, 13, '$'
error_save db "blad zapisywania", 10, 13, '$'
no_error db 10, 13, "program zakonczyl sie bez bledow", '$'

data1 ends

code1 segment




start1:
;---------------------------------------------------------------------------------------------------------------
    call stack_init ; inicjalizacja stosu
	
	call parse_args ; parsuje dane z linii komdend oraz zapisuje je w 
	; in_file_name, out_file_name, key oraz key_len
	
	call open_files ; otwiera pliki oraz zapisuje ich handlery w in_file_handler oraz out_file handler
	
read_loop:

		call read_file ; czyta kolejne 254 bajty z in_file_handler, zapisuje je w file_buf
		; wypełnia również file_buf_len (stopień wypełnienia bufora)
		
		call check_loop_condition ; sprawdza czy zostały przeczytane jakieś bajty (sprawdza, czy file_buf_len == 0) 
		je escape_loop	; jeśli tak to wychodzimy z głownej pętli, zadanie zostało wykonane
		
		mov dx, offset file_buf
		mov ax, seg file_buf   ; wypisanie bufora, czyli zawartości wczytanych danych
		call print
		
		call xor_proc; xoruje file_buf z key oraz zapisuje wynik w file_buf 
		
		call save_to_file; zapisuje zaszyfrowany fragment do pliku wyjściowego
		
		call empty_buffer; wypełnia file_buf od nowa znakiem '$'
		
		jmp read_loop
		; tu koniec pętli
		
escape_loop:
	call close_files; zamyka pliki in_file_handler oraz out_file_handler
	
	mov dx, offset no_error
	mov ax, seg no_error; wypisuje informacje o zakonczeniu bez błędów
	call print
	
	call end_program; kończy działanie programu
;---------------------------------------------------------------------------------------------------------------











; procedury
open_files:
	; otwieranie pliku wejsciowego, handler zapisywany najpierw w ax
	; a następnie w in_file_handler
	mov ax, seg in_file_name
	mov ds, ax
	mov dx, offset in_file_name  
	mov ax, 3d02h 
	int 21h
	jc open_error
	
	mov cx, ax
	
	mov ax, seg in_file_handler
	mov ds, ax
	mov bx, offset in_file_handler
	mov word ptr ds:[bx], cx
	
	
	; otwieranie pliku wyjsciowego, handler zapisywany najpierw w ax
	; a następnie w out_file_handler
	mov ax, seg out_file_name
	mov ds, ax
	mov dx, offset out_file_name
	mov ax, 3d02h 
	int 21h
	jc open_error
	
	mov cx, ax
	
	mov ax, seg out_file_handler
	mov ds, ax
	mov bx, offset out_file_handler
	mov word ptr ds:[bx], cx

	ret
	open_error:
	mov dx, offset error_open
	mov ax, seg error_open        ; obsługa błędu (flaga CF przy otwieraniu)
	call print
	call end_program
	
	
	
read_file:
	; czytanie z pliku wejsciowego
	mov ax, seg in_file_handler
	mov ds, ax
	mov si, offset in_file_handler
	
	mov bx, word ptr ds:[si] 
	mov ax, seg file_buf
	mov ds, ax
	mov dx, offset file_buf ; ds:dx adres bufora
	mov cx, 254
	mov ah, 3fh
	mov al, 0
	int 21h
	jc read_error
	
	; oblicznie wypełnienia bufora na podstawie liczby przeczytanych bajtów 
	mov cx, seg file_buf_len
	mov es, cx
	mov si, offset file_buf_len
	mov byte ptr es:[si], al
	
	ret
	read_error:
	mov dx, offset error_read
	mov ax, seg error_read ; obsługa błędu (flaga CF przy czytaniu)
	call print
	call end_program



stack_init:
	mov ax,seg top1  
    mov ss,ax
    mov sp,offset top1
	ret
	
	

parse_args:
	mov si, 82h ; ustawianie początku parametrów
	xor ax, ax  ; zerowanie licznika znaków do kopiowania
	xor dx, dx	; zerowanie licznika rozróżniającego pliki
	xor cx, cx  ; zerowanie licznika pętli
	
	mov cl, byte ptr ds:[80h] ; pętla ma się wykonać tyle razy ile jest znaków
	; odczytanych z linnii komend. W pętli kilka razy wykonam inkrementacje si (np dla spacji, 
	; żeby jej nie liczyć do ilości znaków do skopiowania). W konsekwencji pętla wykona na końcu
	; kilka pustych przebiegów. Pętla jest skonstruowana w taki sposób, że pierwszy znak po
	; znaku specjalnym jest liczony ale pomija instrukcje warunkowe na początku pętli.
	; Dla tego nie musze się martwić wystąpieniem cudzysłowia otwierającego klucz szyfrujący
	; (jest on zaraz po spacji). Kopiowanie następuje po przejsciu wszystkich znaków do skopiowania
	; oraz napotkaniu spacji bądź cudzysłowia (z wyjątkiem pierwszego cudzysłowia).
	
	args_loop: 
		push cx
		
		cmp byte ptr ds:[si], '"' ; warunek na cudzysłów czyli kopiowanie klucza
		je key_condition
		
		cmp byte ptr ds:[si], ' '; warunek na kopiowanie nazwy pliku wejsciowego
		jne not_cpy              ; lub pliku wyjsciowego
		

		cmp dl, 0				; tutaj następuje rozróznienie na poszczególne pliki
		je in_file_condition	; dl = 0 -> plik wejsciowy
		cmp dl, 1				; dl = 1 -> plik wejsciwy
		je out_file_condition   ; dl = 2 -> nie wykonamy kopiowania nazwy pliku
								; jest to potrzebne przy spacjach zawartych w kluczu
								; aby były one traktowane jak regularny znak
		
		jmp not_cpy             ; jesli żadne z wartunków nie zostały spełnione
								; przechodzę do inkrementacji liczników
		
		in_file_condition:
			call copy_in_file_name ; przechodzę do procedury wykonującej właściwe kopiowanie
			inc dl                 ; inkrementuje licznik rozróżniający pliki
			xor ax, ax             ; zeruje licznik znaków do kopiowania
			inc si				   ; inkrementuje si aby nie liczyć spacji do kopiowania 
								   ; nazwy pliku wyjsciowego
			jmp not_cpy
		out_file_condition:
			call copy_out_file_name	; analogicznie jak wyżej	
			inc dl					
			xor ax, ax
			inc si
			jmp not_cpy
		key_condition:
			dec ax               ; dekrementuje licznik znaków do skopiowania
							     ; ponieważ mimo tego że cudzysłów omija instrukcje 
								 ; warunkowe to jest liczony do znaków do skopiowania
								 ; a tego chce uniknąć. Pozostałe instrukcje analogiczne
			call copy_key
			inc dl
			xor ax, ax
			inc si
			
		not_cpy:
			inc ax
			inc si
			
		pop cx
		loop args_loop
	ret
	
	
	
copy_in_file_name:
	push cx         ; wrzucam wszystkie rejestry na stos
	push si			; aby nie stracic ich wartosci w 
	push ax			; poprzedniej procedurze
	push dx
	
	mov bx, seg in_file_name ; ustawiam es:[di] jako bufor na 
	mov es, bx				 ; nazwe pliku wejsciowego
	mov di, offset in_file_name
	
	sub si, ax  ; cofam si tak, aby ds:[si] wskazywało
	xor cx, cx  ; na pierwszy znak nazwy pliku wejsciowego
	mov cx, ax
	cld
	rep movsb  ; es:[di] <= ds:[si]
	
	pop dx
	pop ax     ; wracam wartości liczników
	pop si
	pop cx
	
	ret
	
	
	
copy_out_file_name:
; procedura całkowicie analogiczna do poprzedniej
	push cx
	push si
	push ax
	push dx
	
	mov bx, seg out_file_name
	mov es, bx
	mov di, offset out_file_name
	
	sub si, ax
	xor cx, cx
	mov cx, ax
	cld
	rep movsb  ; es:[di] <= ds:[si]
	
	pop dx
	pop ax
	pop si
	pop cx
	
	ret
	
	
	
copy_key:
; procedura całkowicie analogiczna do poprzedniej z wyjątkiem
; tego, że długość klucza zapisuje w key_len
	push cx
	push si
	push ax
	push dx
	
	mov bx, seg key_len
	mov es, bx
	mov di, offset key_len
	mov byte ptr es:[di], al
	
	mov bx, seg key
	mov es, bx
	mov di, offset key
	
	sub si, ax
	xor cx, cx
	mov cx, ax
	cld
	rep movsb  ; es:[di] <= ds:[si]
	
	pop dx
	pop ax
	pop si
	pop cx
	
	ret



check_loop_condition:	
	mov ax, seg file_buf_len
	mov ds, ax
	mov bx, offset file_buf_len
	cmp byte ptr ds:[bx], 0    ; dokonuje porówania długości bufora oraz 0
	ret						   ; wynik zapisywany jest we fladze ZF
	
	
	
print:
	mov ds, ax
	mov ah, 9 ; wypisze ds:dx
	int 21h
	ret



xor_proc:
	mov bx, offset file_buf
	mov si, offset key
	mov ax, seg file_buf   ; usatawiam file_buf es:[bx] oraz 
	mov es, ax			   ; key ds:[si]
	mov ax, seg key
	mov ds, ax
	
	xor cx, cx ; zerowanie licznika burofa pliku
	mov cl, byte ptr ds:[file_buf_len] ; ustawienie licznika na liczbe znaków w buforze
	xor ax, ax ; zerowanie licznika klucza
	
	xor_loop:
		push cx
		
		cmp ah, ds:[key_len] ; sprawdzam, czy klucz się już skończył
		jne no_key_shift	 ; jeśli nie to kontynuuje xorowanie
		
		xor ah, ah           ; jeśli klucz się skońćzył to przesuwam
		mov si, offset key   ; jego licznik spowrotem na początek
		
	no_key_shift: 
		mov al, byte ptr es:[bx]   ; pobieram znak z file_buf
		mov dh, byte ptr ds:[si]   ; pobieram znak z key

		xor al, dh                 ; dokonuje właściwego szyfrowania

		mov byte ptr es:[bx], al   ; wynik zapisuje spowrotem w buforze

		inc bx					   ; inkrementuje licznik file_buf
		inc si                     ; inkrementuje licznik key
		inc ah                     ; inkrementuje licznik znaków key
		
		pop cx
		loop xor_loop
	ret
	


save_to_file:
	; procedura zapisuje zaszyfrowane fragmenty
	; cyklicznie do pliku wejsciowego
	mov ax, seg out_file_handler
	mov ds, ax
	mov si, offset out_file_handler
	
	mov bx, word ptr ds:[si] 

	mov ax, seg file_buf
	mov ds, ax
	mov dx, offset file_buf ; ds:dx adres bufora
	xor cx, cx
	mov cl, byte ptr ds:[file_buf_len] ; zapisuje tyle bajtów ile zostało 
									   ; wpisane do bufora	
	mov ah, 40h						   
	int 21h
	jc save_error
	
	ret
	save_error:
	mov dx, offset error_save
	mov ax, seg error_save ; obsługa błędu (flaga CF przy zapisywaniu)
	call print
	call end_program



empty_buffer:
	; cały bufor wypełniam od nowa znakiem '$'
	mov ax, seg file_buf
	mov ds, ax
	mov bx, offset file_buf
	xor cx, cx
	mov cl, 255
	buf_loop:
		push cx
		mov byte ptr ds:[bx], '$'
		inc bx
		pop cx
		loop buf_loop
		
	ret



close_files:
	; zamykam pliki za pomocą handlerów
	; in_file_handler oraz out_file_handler
	mov ax, seg in_file_handler
	mov ds, ax
	mov si, offset in_file_handler
	
	mov bx, word ptr ds:[si] 
	mov ah, 3eh
	int 21h
	
	mov ax, seg out_file_handler
	mov ds, ax
	mov si, offset out_file_handler
	
	mov bx, word ptr ds:[si] 
	mov ah, 3eh
	int 21h
	
	ret	
	
	
	
end_program:
	mov al, 0
    mov ah, 4ch   
    int 21h 



code1 ends
	

stos1 segment stack
    dw 100 dup(?)
top1 dw ?
stos1 ends 

end start1

