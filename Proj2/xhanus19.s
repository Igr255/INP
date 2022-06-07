; Vernamova sifra na architekture DLX
; igor hanus xhanus19


        .data 0x04          ; zacatek data segmentu v pameti
login:  .asciiz "xhanus19"  ; <-- nahradte vasim loginem
cipher: .space 9 ; sem ukladejte sifrovane znaky (za posledni nezapomente dat 0)

        .align 2            ; dale zarovnavej na ctverice (2^2) bajtu
laddr:  .word login         ; 4B adresa vstupniho textu (pro vypis)
caddr:  .word cipher        ; 4B adresa sifrovaneho retezce (pro vypis)

        .text 0x40          ; adresa zacatku programu v pameti
        .global main        ; 

main:   ; sem doplnte reseni Vernamovy sifry dle specifikace v zadani
	addi r29, r0, 0; COUNTER
	addi r13, r0, 0; SWITCH between odd and even 0-> even, 1-> odd	

while:
	lb r17, login+0(r29) ; retrieve next input symbol
	slti r28, r17, 97 ; 
	bnez r28, last
	nop
	nop
do:	
	bnez r13, setOdd ; check wether it is an odd or even index
	nop
	nop
	addi r17, r17, 8 ; add it to the reg with original character

continue:
	sgti r28, r17, 122 ; if r17 > 122 -> r28 = 1
	bnez r28, isLarger
	nop
	nop

	slti r28, r17, 97 ; if r17 < 97 -> r28 = 1
	bnez r28, isLower
	nop
	nop
next:
	sb cipher+0(r29), r17 ; SAVE byte to output value
	sgti r28, r29, 6 ; if counter is large than 6 [indexing is 0-7] + [8] is \0 skip to end and add \0
	bnez r28, last	
	nop
	nop

	addi r29, r29, 1 ; COUNTER++
	xori r13, r13, 1 ; SWITCH between 0 and 1	

	j while
	nop
	nop

isLarger:
	subi r17, r17, 122 ; RES - HIGH
	subi r17, r17, 1  ; (RES - HIGH) - 1
	addi r17, r17, 97 ; (RES - HIGH) - 1 + LOW
	j next
	nop
	nop

isLower:
	;res = res - low + high +1
	subi r17, r17, 97 
	addi r17, r17, 1  
	addi r17, r17, 122
	j next
	nop
	nop

setOdd:
	addi r17, r17, -1 ; sub it to the reg with original character
	j continue
	nop
	nop

last:
	addi r29, r29, 1
	sb cipher+0(r29), r0

end:    addi r14, r0, caddr ; <-- pro vypis sifry nahradte laddr adresou caddr
        trap 5  ; vypis textoveho retezce (jeho adresa se ocekava v r14)
        trap 0  ; ukonceni simulace
