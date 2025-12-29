;*******************************************************************************
;
;	4 HANELI 7 SEGMENT LED GOSTERGE
;	BASIT BASLANGIC SEVIYESI
;	7SEG_SIMPLE.ASM	GELISTIRME DOSYASI
;	SURUM 1.0	22.12.2025
;
;	YAZAR: METE CESMECI
;
;	PIC 16F84A	FOSC = 4 MHz, KRISTAL(_XT_OSC) 
;	INSTRUCTION CYCLE TIME 4TOSC= 4/FOSC = 1us
;
;*******************************************************************************
;
; DAHILI EEPROMDA TUTULAN 4 SAYIYI GOSTERGEYE YAZAR.
; 7 SEGMENT ABCDEFG VE NOKTA PORTB 01234567 BAGLI
; 4 HANE PORTA 0123 BAGLI
; 
; 
;
;*******************************************************************************
;
;	NOTASYON
;	"Hungarian Notation" benzeri "Snake Notation"
; b_ bit, r_ register, p_ pointer, a_ adres, j_ atlama noktasi, c_ altprogram
; f_ flag, i_ giris port, o_ cikis port, io_ g/c port, buyuk harf sabitler
; tc_ zaman sabiti
;*******************************************************************************


;*******************************************************************************
;
; Derleyici ve uC secim direktifleri
;
;*******************************************************************************
LIST R=DEC, F=INHX8M, x=OFF
PROCESSOR PIC16F84A

#include <P16F84A.inc>

; CONFIG opsiyon tanimlari p16f84a.inc dosyasinda

__CONFIG _XT_OSC & _WDT_OFF & _PWRTE_OFF & _CP_OFF

;*******************************************************************************
;	KOD BURADAN BASLAR
;*******************************************************************************

#define	bank0	bcf	STATUS, RP0
#define	bank1	bsf	STATUS, RP0

;*******************************************************************************
;	SABITLER
;*******************************************************************************

;	SISTEM SABITLERI
OPTIONWORD	equ	B'10000100'	;ps=32, psa=tmr0, PB pullup res yok
OPTIONWORP	equ	B'00000100'	;ps=32, psa=tmr0, PB pullup res var
INTCONWORD	equ	B'00000000'	;Kesme kullanilmiyor
TRIS_A		equ	B'00010000'	;PORTA giris/cikis pin ayarlari
TRIS_B		equ	B'00000000'	;PORTB giris/cikis pin ayarlari


;*******************************************************************************
;	GIRIS-CIKIS TANIMLARI
;*******************************************************************************
; 
; Buradakiler devrenize gore degisir
; Benim devremde ortak anot(CA) gosterge kullanildi
; Segmentler ULN2003 entegresi ile suruluyor,
; dolayisiyla PORTB'ye yazilacaklar "active high" lojik seviyelerle anlamli
; Haneler, yani ortak anotlar BC327 PNP transistorler ile suruluyor
; dolayisiyla PORTA'ya yazilacaklar "active low" lojik seviyelerle anlamli
;
;	PORT B BAGLANTISI
; 7 segment, active high
#define		o_a		PORTB,0		; Led gosterge a segmenti
#define		o_b		PORTB,1		; Led gosterge b segmenti
#define		o_c		PORTB,2		; Led gosterge c segmenti
#define		o_d		PORTB,3		; Led gosterge d segmenti
#define		o_e		PORTB,4		; Led gosterge e segmenti
#define		o_f		PORTB,5		; Led gosterge f segmenti
#define		o_g		PORTB,6		; Led gosterge g segmenti
#define		o_p		PORTB,7		; Led gosterge nokta segmenti

;	PORT A BAGLANTISI
; 4 hane, active low
#define		o_dis0	PORTA,0		; Gosterge hanesi 0
#define		o_dis1	PORTA,1		; Gosterge hanesi 1
#define		o_dis2	PORTA,2		; Gosterge hanesi 2
#define		o_dis3	PORTA,3		; Gosterge hanesi 3


;*******************************************************************************
;	YAZMAC TANIMLARI (0x0C..0x4F) 68 BYTE RAM
;	ORG	0x0C
;*******************************************************************************
;
;
;
r_dispbuf	equ	0x0C		; +4 0C-0F 4 byte gosterge hafizasi alani
r_discnt	equ	0x10		; hane sayaci
r_pdispbuf	equ	0x11		; gosterge hafizasinin adresini tutan pointer


;*******************************************************************************
;	PROGRAM KODLARI
;*******************************************************************************
;
;*******************************************************************************
;	PROGRAM BASI
;*******************************************************************************
;
	org     0x00
	movlw	0x00
	movwf	STATUS
	goto	j_basla

;*******************************************************************************
;	KESME VEKTORU
;*******************************************************************************
;
;	org     0x04
;	goto	is_inttmr0


;*******************************************************************************
;	TABLOLAR
;*******************************************************************************
;Bu tip tablolarin indekslemesi bagil adresleme kisitlarina iliskili
;O sebeple datasheet ve application note araciligiyla ne anlatiliyorsa uyulmali
;Bu sinif uC icin tablolar program bellegin ilk bloklarinda kalmali
;PCL 8bit, dolayisiyla 256 nokta adresleyebilir, burada 20 noktamiz var

t_segment	
; segment	  .gfedcba
; bit number  76543210
	addwf	PCL, F
	retlw 	B'00111111'	;0		0
	retlw	B'00000110'	;1		1
	retlw	B'01011011'	;2		2
	retlw	B'01001111'	;3		3
	retlw	B'01100110'	;4		4
	retlw	B'01101101'	;5		5
	retlw	B'01111101'	;6		6
	retlw	B'00000111'	;7		7
	retlw	B'01111111'	;8		8
	retlw	B'01101111'	;9		9
	retlw	B'01110111'	;A		10
	retlw	B'01111100'	;b		11
	retlw	B'00111001'	;C		12
	retlw	B'01011110'	;d		13
	retlw	B'01111001'	;E		14
	retlw	B'01110001'	;f		15
	retlw	B'00000000'	;Bosluk	16
	retlw	B'01000000'	;-		17
	retlw	B'00001000'	;_		18
	retlw	B'00000001'	;~		19




;*******************************************************************************
;	PROGRAM
;*******************************************************************************
;
j_basla
	bank1
	movlw	TRIS_A			;PORTA ayarla
	movwf	TRISA

	movlw	TRIS_B			;PORTB ayarla
	movwf	TRISB
	
	movlw   OPTIONWORP		;OPTION ayarla
	movwf	OPTION_REG
	bank0

	movlw	INTCONWORD		;Kesmeleri ayarla
	movwf	INTCON 

	clrf    PCLATH			;upper pc = 0

	clrf    PORTA
	clrf	PORTB

	movlw	r_dispbuf		;pointer'a gosterge hafiza adresi atanir
	movwf	r_pdispbuf

	clrf	r_dispbuf		;gosterge hafizasi temizlenir
	clrf	r_dispbuf+1
	clrf	r_dispbuf+2
	clrf	r_dispbuf+3

	movlw	B'00000001' 	;hane sayaci = birinci hane
	movwf	r_discnt		;sonra ileride her hane icin bir sola kaydirilacak

	call	c_numaragoster	;Gostergeye yazilacaklari EEPROMdan getir

j_main						;ana program sonsuz dongu
	call	c_gosterge
	goto	j_main


;*******************************************************************************
;	NUMARAYI EEPROM'DAN OKUYUP GOSTERGE HAFIZASINA YAZAN ALTPROGRAM
;
; EEPROM'daki 0. byte gostegre bellegindeki en sol ilk yazmaca yazilir
; sonrakiler sirayla devam eder, EEPROM'dan 4 rakam getirilir
;*******************************************************************************
;
c_numaragoster
	movlw	0x00
	call	c_read_eeprom
	movwf	r_dispbuf+3
	movlw	0x01
	call	c_read_eeprom
	movwf	r_dispbuf+2
	movlw	0x02
	call	c_read_eeprom
	movwf	r_dispbuf+1
	movlw	0x03
	call	c_read_eeprom
	movwf	r_dispbuf
	retlw	0



;*******************************************************************************
;	DISPLAY ALTPROGRAMI
;
; 4 hane hafiza yerinden sirasi gelenin sakladigi rakam
; pointer araciligiyla getirilir
; Rakamin karsiligi 7 segment ledlerden hangilerinin yanacagi tablodan getirilir
; PORTB'ye yazilir
; Hangi hanenin yanacagi hane sayacinda tutulur ve PORTA'ya yazilir
; Sonraki haneyi isaret etmek icin hane sayaci bir sola kaydirilir
; Yani en sagdaki ilk hane, en soldaki son hane (right justified LSB).
; Tüm ledler ve haneler sondurulur ki gosterge sonukken bir sonraki hane icin
; hazirlik yapilirken, gostergede haneler arasi hayalet goruntuler olusmasin
;*******************************************************************************
;
c_gosterge
	movf	r_pdispbuf, W	;index yazmaca pointerdeki adresi aktar
	movwf	FSR
	movf	INDF, W			;isaretlenen gosterge hafizasindaki rakami getir
	call	t_segment		;gosterge hafizasindaki rakamin 7 segment getir
	movwf	PORTB			;portb'ye yaz

	comf	r_discnt, W		;ilgili haneyi porta'ya yaz
	movwf	PORTA			;active low oldugu icin lojik degilini aldik

j_disdev
	incf	r_pdispbuf, F	;pointerdeki adresi bir ilerlet
	bcf		STATUS, C
	rlf		r_discnt, F		;hane sayacini bir sola kaydirip siradakini isaretle
	btfss	r_discnt, 4		;4 hane var, 4. bit 1 mi diye test edilir
	goto	j_disson
	movlw	1				;4 hane gosterildi birinciye don
	movwf	r_discnt
	movlw	r_dispbuf		;pointeri basa al
	movwf	r_pdispbuf
j_disson
	movlw	B'00001111'		;her turda butun haneleri sondur
	movwf	PORTA			;cunku yan hanenin 7segment portb'ye cikacak
	movlw	B'00000000'		;cunku LED'lerin sondugunden emin olmak gerek
	movwf	PORTB			
	retlw	0
;*******************************************************************************
;
; Zamanlama soyle hesaplanir;
; PIC16F84A datasheet Table 7-2'den bakarak,
; her komut 1 Tcycle, su komutlar 2 Tcycle; call, goto, retlw
; btfss komutu atlama yapmazsa 1 atlama yaparsa 2 Tcycle
;
; Bir hanedeki ledlerin yanik kalma suresi TON
; ilk "movwf PORTA" 'dan itibaren ledler yanar sonraki "movwf PORTA" ile soner
; aradaki komutlarin toplam suresi
; 8 Tcycle, yani ledlerin TON = 8us
; son hanede ayrica "movlw 1" ile baslayan 4 komut fakat bu sefer "goto" yok
; toplam suresi 11 Tcycle, yani son hanenin ledlerin TON = 11us
; 
; Bir hanedeki ledlerin sonuk kalma suresi TOFF
; Bir hane yanarken digerleri sonuk.
; j_main dongusu 4 Tcycle
; c_gosterge toplam suresi butun komut zamanlarini toplayinca 24 Tcycle
; 24 Tcycle(c_gosterge) + 4 Tcycle(j_main) = 28 Tcycle, 28us hane suresi
; diger 3 hane biri son hane 28 + 28 + 31 = 87 Tcycle toplam diger hane suresi
; 4 hanenin toplam peryodu TP = 28 + 28 + 28 + 31 = 115 Tcycle
; gosterge tazeleme hizi 1/115us = 8696Hz
; TOFF = TP - TON = 115 - 8 = 107 Tcycle, yani 107us, (son hane 115-11=104us)
; Bir hanenin yanik-sonuk orani veya duty cycle degeri
; %d = 100*TON/TP = 100*8us/115us = %7
; Yanik-sonuk oraninin teorik maksimum alabilecegi deger %25
; cunku 4 hane var, bir periyod zamani hane sayisina bolunur.
; 
; Bir hanenin LED parlakligi akima ve yanik-sonuk oranina iliskili.
; Benim devremde Kingbright SA08-11SRWA kullandim, kirmizi renk led
; Devremde segmentlere seri 150ohm direnc var.
; Datasheet bakarak
; LED VF = 1.8V , BC327 VCEsat = 0.2V , ULN2007 VCEsat = 0.7V alirsak
; VCC = 5V
; ILED = (VCC - VCEsatBC327 - VCEsatULN2003 - VFLED)/R
; ILED = (5 - 0.2 - 0.7 - 1.8)/150 = 15.3mA
; Kingbright SA08-11SRWA datasheet bakarak
; 15.3mA surekli akimda led parlakligi 1.5*36mcd = 54mcd
; %7 duty cycle var. Insan goz ile 54mcd * 0.07 = 3.8mcd algilar
;
; Bir hanenin maksimum akimi butun ledler yanik iken led akimlarinin toplamidir
; IHANE = 7 * ILED = 7 * 15.3mA = 107mA
;
; Haneler zaman paylasimli yakilip sonduruldugu icin,
; herhangi bir anda yalniz bir hane yanik digerleri sonuk oldugu icin
; toplam gosterge akimi IGOS = IHANE = 107mA
; Butun hanelerin TON sureleri toplami = 8 + 8 + 8 + 11 = 35us
; Dolayisiyla gostergenin akim cekme orani %dt = TONt/TP = 35us/115us = %30.4
; Gostergenin zamana bagli ortalama akimi
; IGOSort = IGOS * %dt = 107mA * 0.304 = 33mA
;
;
;c_gosterge
;	movf	r_pdispbuf, W	;1 Tcycle
;	movwf	FSR				;1 Tcycle
;	movf	INDF, W			;1 Tcycle
;	call	t_segment		;2 Tcycle + 4 Tcycle(t_segment tablo okumasi)
;	movwf	PORTB			;1 Tcycle
;
;	comf	r_discnt, W		;1 Tcycle
;	movwf	PORTA			;1 Tcycle
;
;j_disdev
;	incf	r_pdispbuf, F	;1 Tcycle
;	bcf		STATUS, C		;1 Tcycle
;	rlf		r_discnt, F		;1 Tcycle
;	btfss	r_discnt, 4		;atlamazsa 1 Tcycle,atlarsa 2 Tcycle
;	goto	j_disson		;2 Tcycle
;	movlw	1				;1 Tcycle
;	movwf	r_discnt		;1 Tcycle
;	movlw	r_dispbuf		;1 Tcycle
;	movwf	r_pdispbuf		;1 Tcycle
;j_disson
;	movlw	B'00001111'		;1 Tcycle
;	movwf	PORTA			;1 Tcycle
;	movlw	B'00000000'		;1 Tcycle
;	movwf	PORTB			;1 Tcycle			
;	retlw	0				;2 Tcycle
;
;
;j_main
;	call	c_gosterge		;2 Tcycle
;	goto	j_main			;2 Tcycle
;
;
;t_segment	
;	addwf	PCL, F			;2 Tcycle !Datasheet 1 Tcycle diyor fakat olcum 2
;	retlw 	B'00111111'		;2 Tcycle



;*******************************************************************************
;	EEPROM YAZMA-OKUMA ALTPROGRAMLARI
;*******************************************************************************
;
;	EEPROM OKUMA ALTPROGRAMI
;	GIRIS:	w, eeprom adresi
;	CIKIS:	w
;	BOZ  :	w
;	IS   :	eepromun istenilen yerinden bir bayt okunuyor
;
c_read_eeprom
	movwf   EEADR
	bank1
	bsf     EECON1,RD
	bank0
	movf    EEDATA,W
	return

;
;	EEPROM YAZMA ALTPROGRAMI
;	GIRIS:	w, eeprom adresi
;	CIKIS:	yok
;	BOZ  :	w
;	IS   :	eepromun istenilen yerine bir bayt yaziliyor
;
c_write_eeprom
	movwf   EEDATA
	bank1
	bsf     EECON1,WREN
	movlw   0x55
	movwf   EECON2
	movlw   0xAA
	movwf   EECON2
	bsf     EECON1,WR
j_wr_loop
	btfsc	EECON1,WR
	goto	j_wr_loop
	bcf		EECON1,WREN
	bank0
	return

	
;*******************************************************************************
;	GOSTERGEDE GOSTERILECEK NUMARA
;	BU VERI DAHILI EEPROMDA KAYITLIDIR. PIC16F84A ICIN MAKSIMUM 64 BYTE.
;*******************************************************************************
;
	org	H'2100'		; EEPROM verileri baslangic adresi
	DE	1,2,3,4,0,9,8,7,6,5,4,3,2,1,0,10,11,12,13,14,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	end

