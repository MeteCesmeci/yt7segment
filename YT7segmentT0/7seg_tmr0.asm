;*******************************************************************************
;
;	4 HANELI 7 SEGMENT LED GOSTERGE
;	ORTA SEVIYE
;	7SEG_TMR0.ASM	GELISTIRME DOSYASI
;	SURUM 1.0	28.12.2025
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
; LDR + 1nF PORTA 4.PIN BAGLI, ORTAM ISIGI OKUNUR
; GOSTERGE PARLAKLIGI ORTAM AYDINLIK DUZEYINE GORE DEGISTIRILIR
; OLAY OLUSLARI TMR0 KESMESI ILE SENKRONLANIR, HER 1ms'de BIR KESME
; GOSTERGE PARLAKLIGI YAZILIM PWM ILE LED YANMA SURESI DEGISTIRILEREK YAPILIR
; PORTA 4.PIN UZERINDEN RC DOLMA ZAMANINA BAKARAK YAZILIM ADC OLUSTURULUR
; HER 2s'de BIR, SIRADAKI SONRAKI 4 HANELI RAKAM GOSTERILIR
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
OPTIONWORD	equ	B'10000001'	;ps=4, psa=tmr0, PB pullup res yok
OPTIONWORP	equ	B'00000001'	;ps=4, psa=tmr0, PB pullup res var
INTCONWORD	equ	B'00100000'	;sadece tmr0 kesmesi kullaniliyor, T0IE = 1
TRIS_A		equ	B'00000000'	;PORTA giris/cikis pin ayarlari
TRIS_A4IN	equ	B'00010000'	;PORTA 4. pin giris digerleri cikis pin ayarlari
TRIS_B		equ	B'00000000'	;PORTB giris/cikis pin ayarlari

;	ZAMAN SABITLERI
tc_T0_PER	equ	9		;255-250+4=9 1MHz/4/250 1000Hz, her 1ms kesme
;tc_TON karsiligi olarak parlakligi belirleyen asagidaki degerler kullanilacak
tc_ITAM		equ	45		;Gosterge parlakligi tam, TON = 20 Tcycle * 45 = 900us
tc_IYARIM	equ	25		;Gosterge parlakligi yarim	TON = 500us
tc_IDUSUK	equ	10		;Gosterge parlakligi en dusuk TON = 200us
tc_CHGPER	equ	247		;4 haneli rakam degisim zamani 8*256ms = 2s(yaklasik)

sz_numarray	equ 24		;EEPROM'dan okunacak rakam sayisi

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
#define		o_p		PORTB,7		; Led gosterge nokta segmenti, kullanilmadi

;	PORT A BAGLANTISI
; 4 hane, active low
#define		o_dis0	PORTA,0		; Gosterge hanesi 0
#define		o_dis1	PORTA,1		; Gosterge hanesi 1
#define		o_dis2	PORTA,2		; Gosterge hanesi 2
#define		o_dis3	PORTA,3		; Gosterge hanesi 3
#define		io_adc	PORTA,4		; Gosterge hanesi 3


;*******************************************************************************
;	YAZMAC TANIMLARI (0x0C..0x4F) 68 BYTE RAM
;	ORG	0x0C
;*******************************************************************************
;
;
;
r_dispbuf	equ	0x0C		; +4 0C-0F 4 byte gosterge bellek alani
r_discnt	equ	0x10		; hane sayaci
r_pdispbuf	equ	0x11		; gosterge belleginin adresini tutan pointer
r_stattemp	equ 0x12		; kesme aninda gecici STATUS saklama yeri
r_wtemp		equ	0x13		; kesme aninda gecici W saklama yeri
r_flags		equ	0x14		; cesitli durum bayraklari
	#define	f_tick			r_flags, 0
	#define	f_adcrun		r_flags, 1
	#define	f_numchg		r_flags, 2
	#define	f_reserved3		r_flags, 3
	#define	f_reserved4		r_flags, 4
	#define	f_reserved5		r_flags, 5
	#define	f_reserved6		r_flags, 6
	#define	f_reserved7		r_flags, 7
r_tontimer	equ 0x15		; gosterge TON zamanlayicisi
r_parlaklik	equ 0x16		; gosterge parlakligi burada saklanacak
r_adc		equ	0x17		; yazilim ADC yazmaci
r_timer0	equ	0x18		; 256 kesmelik olay sayaci
r_timer1	equ	0x19		; 256 * buradaki sayi araliklarla bayrak ayarlanir
r_temp		equ 0x1A		; Gecici isler icin
r_pnumarray	equ	0x1B		; sayi dizisinin adresini tutan pointer
r_numarray	equ	0x20		; +16 20-2A sayi dizisi bellek alani


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
	org     0x04
	goto	is_inttmr0


;*******************************************************************************
;	TABLOLAR
;*******************************************************************************
;Bu tip tablolarin indekslemesi bagil adresleme kisitlarina iliskili
;O sebeple datasheet ve application note araciligiyla ne anlatiliyorsa uyulmali
;Bu sinif uC icin tablolar program bellegin ilk bloklarinda kalmali
;PCL 8bit, dolayisiyla 256 nokta adresleyebilir, burada 20 noktamiz var
;
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

	movlw	r_dispbuf		;pointer'a gosterge bellek adresi atanir
	movwf	r_pdispbuf

	clrf	r_dispbuf		;gosterge hafizasi temizlenir
	clrf	r_dispbuf+1
	clrf	r_dispbuf+2
	clrf	r_dispbuf+3

	clrf	r_flags			;durum bayraklari temizlenir

	movlw	B'00000001' 	;hane sayaci = birinci hane
	movwf	r_discnt		;sonra ileride her hane icin bir sola kaydirilacak

; Bu kisim yeni eklendi,zamanlayici yazmaclarina baslangic degerleri yukleniyor
	movlw	tc_IYARIM		;varsayilan parlaklik yari degerde
	movwf	r_parlaklik
	movwf	r_tontimer

	movlw	tc_CHGPER
	movwf	r_timer1

	movlw	r_numarray		;pointer'a sayi dizisi bellek adresi atanir
	movwf	r_pnumarray
	
	
	call	c_numaragoster

	bsf		INTCON, GIE		;Global kesme bitini ayarla, kesmeler aktif

j_main						;ana program sonsuz dongu
	call	c_parlaklikoku	;islem yapmadan cikarsa 5 Tcycle
	call	c_numaradondur	;islem yapmadan cikarsa 5 Tcycle
	call	c_gosterge		;sadece TON sayarsa 8 Tcycle
							;Nasil 8 Tcycle? Soyle ki;
							;call	c_gosterge	2 Tcycle
							;btfss	f_tick		1 Tcycle
							;goto	j_disson	2 Tcycle
							;j_disson
							;decfsz	r_tontimer,F 1 Tcycle
							;return				2 Tcycle
							
	goto	j_main			;2 Tcycle
							;TON icin toplam 20 Tcycle
							;Yani TON sayac degeri 20us'nin katlari olur




;*******************************************************************************
; KESME SERVIS ALTPROGRAMI
;*******************************************************************************
is_inttmr0
;PUSH W, PUSH STATUS
	movwf	r_wtemp			;Kesme girisinde W ve STATUS gecici yere saklanir
	swapf	STATUS, W		;PIC16 serisinde PUSH ve POP yigin komutlari yok
	movwf	r_stattemp		;Datasheet 6.9 Context Saving During Interrupts

	movlw	tc_T0_PER		;Burada belirlenen periyotla TMR0 kesmesi olusacak
	movwf	TMR0			;Burasi dahil 5 Tcycle, zaman sabiti hesabina kat
	bsf		f_tick			;Her 1ms'de bir saat darbesi uret
;	bsf		PORTA, 4		;Test icin
	incfsz	r_timer0, F		;256 kesmede bir, yani 256ms
	goto	j_intson
	bsf		f_adcrun
	incfsz	r_timer1, F		;256*8 kesmede bir, yani yaklasik 2s
	goto	j_intson
	bsf		f_numchg
	movlw	tc_CHGPER
	movwf	r_timer1
j_intson
;POP STATUS, POP W
	swapf	r_stattemp, W	;Kesme cikisinda gecici saklanan W ve STATUS
	movwf	STATUS			;geri yazilir
	swapf	r_wtemp, F		;movf Z zero bayragini etkiler, o nedenle swapf
	swapf	r_wtemp, W

	bcf		INTCON, T0IF	;T0IF kesme servisinde yazilimda sifirlanmali
	retfie


	
;*******************************************************************************
;	NUMARAYI EEPROM'DAN OKUYUP SAYI DIZISI BELLEGINE YAZAN ALTPROGRAM
;
; EEPROM'daki 0. byte sayi dizisi bellegindeki ilk yazmaca yazilir
; sonrakiler sirayla devam eder, EEPROM'dan sz_numarray kadar rakam getirilir
; Iki pointer kullanilir, FSR ve r_temp
; FSR r_numarray adresinden baslar, r_temp 0'dan baslar
; ikisi de her turda bir artirilir, dongu sz_numarray ulasinca durur
;*******************************************************************************
;
c_numaragoster
	movf	r_pnumarray, W	;index yazmaca pointerdeki adresi aktar
	movwf	FSR
	clrf	r_temp			;EEPROM poineri ilk byte isaretle
j_nextnum
	movf	r_temp, W
	call	c_read_eeprom
; IGOS = IHANE akim olcmek icin butun ledler yanmali, rakamlar 8 olmali
; O nedenle call c_read_eeprom comment yapilir
; Asagidaki uncomment yapilir
;	movlw	8
	movwf	INDF			;isaretlenen gosterge hafizasina rakami yaz
	incf	r_temp, F		;pointerleri bir artir
	incf	FSR, F
	movf	r_temp, W		;sz_numarray kadar byte okunduysa bitir
	xorlw	sz_numarray
	btfss	STATUS, Z
	goto	j_nextnum
	retlw	0



;*******************************************************************************
;	GOSTERILECEK SAYI DIZISINDEN 4 HANELIK GOSTERGE PENCERESINE BASAR
;
; Sayi dizisinde sirasi gelen 4 hanenin ilk rakami
; gostegre bellegindeki ilk yazmaca yazilir
; sonrakiler sirayla devam eder
; iki pointer kullanilir, r_pnumarray ve FSR
; r_pnumarray gosterilecek 4 haneli pencere baslangic adresini tutar
; FSR pencere icinden getirilen rakamlarin adresini tutar
; Her f_numchg periyotunda bir pencere pointeri sonraki 4 rakamli numaraya kayar
; sz_numarray kadar rakam diziden okunduysa biter, pointerler basa dondurulur
;*******************************************************************************
;
c_numaradondur
	btfss	f_numchg		;f_numchg 1 ise okuma zamani geldi
	retlw	0				;f_numchg 0 ise cik
	bcf		f_numchg		;bir kere f_numchg islenir, hemen 0 yapilir ki
							;tekrarlamasin, sadece TMR0 peryoduyla calissin
	movf	r_pnumarray, W	;index yazmaca pointerdeki adresi aktar
	movwf	FSR
	movf	INDF, W
	movwf	r_dispbuf+3
	incf	FSR, F
	movf	INDF, W
	movwf	r_dispbuf+2
	incf	FSR, F
	movf	INDF, W
	movwf	r_dispbuf+1
	incf	FSR, F
	movf	INDF, W
	movwf	r_dispbuf
	movlw	4
	addwf	r_pnumarray
	movf	r_pnumarray, W	;sz_numarray kadar byte okunduysa bitir
	xorlw	r_numarray+sz_numarray ;!!! ___lw komutlarda bu toplam < 255 olmali
	btfss	STATUS, Z
	retlw	0
	movlw	r_numarray
	movwf	r_pnumarray
	retlw	0



;*******************************************************************************
;	ISIK DUZEYINI YAZILIM ADC ILE OKUYUP GOSTERGE PARLAKLIGI AYARLAR
;
;
; Yazilim ADC, bir LDR ve 1nF kapasite seri bagli, orta noktasi io_adc bagli
; Baslangic: r_adc = 0 ve io_adc cikis iken 0 yapilir, io_adc giris ayarlanir
; Surec: PORTA 4. pin Schmitt giris 0.8VCC olunca 1 olarak okunur
; 1nF LDR uzerinden dolarken zaman gecer, zaman r_adc ile sayilir
; Bitis: Kapasite gerilimi 0.8VCC olunca io_adc 1 olur ve r_adc sayaci durur
; Boylece RC zaman sabiti okunan yazilim ADC yapilmis olur
; C sabit, R ortam isik duzeyi ile degisiyor
; Parlak ortamda LDR R en kucuk 800R, karanlik ortamda R en buyuk 10M
; LDR en kucuk iken min R belirli zamana karsilik olsun diye seri 10K bagli
; LDR en buyuk iken maks R belirli zamana karsilik olsun diye paralel 100K bagli
;*******************************************************************************
;
c_parlaklikoku
	btfss	f_adcrun		;f_adcrun 1 ise okuma zamani geldi
	retlw	0				;f_adcrun 0 ise cik
	bcf		f_adcrun		;bir kere f_adcrun islenir, hemen 0 yapilir ki
							;tekrarlamasin, sadece TMR0 peryoduyla calissin
							;256ms'de bir calisir
; ADC kismi burasi, kesmeleri kapatmak gerek ki ADC bozulmasin
	bcf		INTCON, GIE		;Global kesme bitini ayarla, kesmeler kapali
	clrf	r_adc
	bcf		io_adc
	bank1
	movlw	TRIS_A4IN		;PORTA ayarla
	movwf	TRISA
	bank0
j_incadc
	incf	r_adc, F
	btfss	io_adc
	goto	j_incadc
	bank1
	movlw	TRIS_A			;PORTA ayarla
	movwf	TRISA
	bank0
	bsf		INTCON, GIE		;Global kesme bitini ayarla, kesmeler aktif
; ADC bitti, okunani degerlendirmek ve parlaklik ayarlamak kismi burasi
j_tam
	movf	r_adc, W
	sublw	5				;okunan 5'ten kucukse tam parlaklik
	btfss	STATUS, C
	goto	j_yarim
	movlw	tc_ITAM
	movwf	r_parlaklik
	retlw	0
j_yarim
	movf	r_adc, W
	sublw	15				;okunan 5'ten buyuk 15'ten kucukse yarim parlaklik
	btfss	STATUS, C
	goto	j_dusuk			
	movlw	tc_IYARIM
	movwf	r_parlaklik
	retlw	0
j_dusuk
	movlw	tc_IDUSUK		;okunan 15'ten buyuk, dusuk parlaklik
	movwf	r_parlaklik
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
; Bu kisim yeni eklendi, f_tick 1 ise gosterge isletiliyor, 0 ise is yapmaz
	btfss	f_tick			;f_tick 1, yani gosterme zamani geldi
	goto	j_disson		;f_tick 0, islem yapmadan devam
	bcf		f_tick			;bir kere f_tick islenir, hemen 0 yapilir ki
							;tekrarlamasin, sadece TMR0 peryoduyla calissin
							;buradan j_disson'a kadar kisim 1ms'de bir calisir
							;j_disson sonrasi her c_gosterge cagrilisinda calisir

	movf	r_parlaklik, W	;Parlaklik ayarini kullan		
	movwf	r_tontimer

;Bu kisim artik 1ms peryotta bir calistirilir
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
; Bu kisim yeni eklendi, TON doldu ise ledleri kapatir
; Bu kisim c_gosterge her cagrildiginde calisir ki TON sayaci hizli islesin
	decfsz	r_tontimer,F	;TON zamanini belirleyecek register islemleri
	return
	movf	r_parlaklik, W	;Sayaci basa al		
	movwf	r_tontimer

	movlw	B'00001111'		;her turda butun haneleri sondur
	movwf	PORTA			;cunku yan hanenin 7segment portb'ye cikacak
	movlw	B'00000000'		;cunku LED'lerin sondugunden emin olmak gerek
	movwf	PORTB			
	return
;*******************************************************************************
;
; Zamanlama soyle hesaplanir;
; Basit uygulamadakinden farkli olarak artik c_gosterge isletilmesi f_tick ile.
; f_tick her 1ms'de bir olan TMR0 kesmesi ile 1 yapilir, f_tick 1 ise bu
; altprogram isletilir. Boylece bir hane zamani THANE 1ms'ye uzatilmis olur
;
; Bir hanedeki ledlerin yanik kalma suresi TON
; Artik TON'u istedigimiz gibi uzatabilir hale gelmis oluruz
; TON koddaki maksimum suresi TONmaks = 1ms-(is_inttmr0+c_gosterge+main dongusu)
; olabilir, 900us'ye kadar cikarilabilir. 
; Kalan 100us'de 100 komut kod isletilebilir
; Main dongusu icinde cagrilan programlarin Tcycle toplami arttikca 900us'den
; yemek zorunda kaliriz. Aydinlik duzeyi, ADC ve rakam dondurme ozellikleri
; eklendikce onlarin islem suresi kadar 1ms'den kisaltmak zorunda kaliriz.
; Daha uzun oldugunda diger altprogram islerine zaman kalmaz ve
; girisimler, karasizliga sebep olan yan etkiler baslar.
;
; Bir hanedeki ledlerin sonuk kalma suresi TOFF
; Bir hane yanarken digerleri sonuk.
; Artik TOFF = 4*THANE - TON olarak hesaplayabilir hale geldik.
; Cunku tum haneler esit sureli, TP = 4*THANE olarak hesaplanabilir oldu
; THANE = TMR0 kesme periyotu = 1ms, TP = 4 * 1ms = 4ms
; Gosterge tazeleme hizi 1/TP = 250Hz
;
; Bir hanenin yanik-sonuk orani veya duty cycle maksimum degeri
; %d = 100*TON/TP = 100*900us/4ms = %22.5
;
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
; %22.5 duty cycle var. Insan goz ile 54mcd * 0.225 = 12.15mcd algilar
;
; Bir hanenin maksimum akimi butun ledler yanik iken led akimlarinin toplamidir
; IHANE = 7 * ILED = 7 * 15.3mA = 107mA
;
; Haneler zaman paylasimli yakilip sonduruldugu icin,
; herhangi bir anda yalniz bir hane yanik digerleri sonuk oldugu icin
; toplam gosterge akimi IGOS = IHANE = 107mA
; Butun hanelerin TON sureleri toplami = 4*TONmaks = 4 * 900us = 3.6ms
; Dolayisiyla gostergenin akim cekme orani %dt = TONt/TP = 3.6ms/4ms = %90
; Gostergenin zamana bagli ortalama akimi
; IGOSort = IGOS * %dt = 107mA * 0.90 = 96mA
;
;
; Bu hesap bize kullandigimiz yontemde TON suresi icin sayac olarak bir dongu
; kullanmis olmamiz sebebiyle, eklemek isteyecegimiz
; diger ozellik altprogramlarinin TON sayac hesabina dahil edilmek zorunda olmasi,
; toplam Tcycle suresinin degismesi ve toplamin katlariyla islem yapildigindan
; sure ayar birim zamani buyudugunden hassas ayar imkani kalmaz.
; ADC olcum suresi TADC yine bir "bitmeden cikilmayan dongu" olmasi sebebiyle
; c_parlaklikoku her isletildiginde gosterge sureclerini etkiler.
; Tum bu sakincalar; 1ms'lik dilimlere sigacak 1000 Tcycle(1000 komut)
; kaynagimizi olasi en yuksek performansta degil de, 
; ancak yari performansta kullanabiliyor oldugumuzu gosterir.
;
; Mikrokontrolorun zaman ve kod kaynaklarini daha etkili kullanmak icin
; main dongusu veya altprogramlar icinde hicbir sekilde 
; do-while, do-until, for-next benzeri "isi bitmeden cikilmayan donguler"
; kullanmamak gerekir.
;
; Ileri seviye programlamada hersey zaman cizgisinde konumu ve suresi
; tam tanimlanmis olarak tasarlanmalidir.
; Bu orta seviye program, sakincalari iyi sekilde gostermektedir.
; Burada gosterilen durum icin akim ve osiloskop olcumleri,
; deney duzeni fotograflari eklenmistir.
;


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
	DE	1,2,3,4,0,9,8,7,6,5,4,3,2,1,0,10,11,12,13,14,15,14,13,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	end

