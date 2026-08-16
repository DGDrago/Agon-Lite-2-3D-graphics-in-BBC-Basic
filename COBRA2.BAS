   10 REM ---------------------------------------------------------
   20 REM  Cobra MkIII - vrtnja iz medjuspremnika VDP-a
   30 REM  Agon Light 2, cisti BBC BASIC
   40 REM
   50 REM  Svih NA% polozaja izracuna se jednom pri pokretanju i
   60 REM  spremi na VDP kao gotov niz VDU naredbi: brisanje pa
   70 REM  MOVE/DRAW za svaki vidljivi brid. Okvir je onda samo
   80 REM      VDU 23,0,&A0,id;1
   90 REM  sest bajta - ni geometrija ni crtanje ne diraju eZ80.
  100 REM
  110 REM  Brisanje ne pokriva cijeli ekran nego samo pravokutnik
  120 REM  u koji brod stane u svim polozajima; PROCbox ga izmjeri
  130 REM  unaprijed. Za jednu os to je oko 2,7 puta manje piksela.
  140 REM
  150 REM  Brojac: MOS uvecava TIME za 2 po VBLANK-u, sto je racun
  160 REM  za 50 Hz. Mod 136 radi na 60 Hz pa TIME ide 20% prebrzo;
  170 REM  zato 1920 a ne 1600.
  180 REM
  190 REM  Tipke: Q kraj, SPACE pauza, + / - brze i sporije
  200 REM ---------------------------------------------------------
  210 NA%=64 : BI%=&2000
  220 NC%=4 : NP%=12 : NE%=38 : NF%=13
  230 MODE 136
  240 VDU 23,0,&C0,0 : REM piksel koordinate, ishodiste gore lijevo
  250 VDU 23,1,0
  260 ON ERROR VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : REPORT : PRINT " u liniji ";ERL : END
  270 DIM SX%(27),SY%(27),SI%(63),PW%(12),EM%(37)
  280 DIM EA%(37),EB%(37),NX%(12),NY%(12),NZ%(12)
  290 DIM CI%(3),CY%(3),CZ%(3),PA%(11),PB%(11),PX%(11),PY%(11),PZ%(11)
  300 FOR I%=0 TO 63 : SI%(I%)=INT(256*SIN(I%*PI/32)+0.5) : NEXT
  310 PW%(0)=1 : FOR I%=1 TO 12 : PW%(I%)=PW%(I%-1)*2 : NEXT
  320 RESTORE 1360
  330 FOR I%=0 TO NC%-1 : READ CI%(I%),CY%(I%),CZ%(I%) : NEXT
  340 RESTORE 1380
  350 FOR I%=0 TO NP%-1 : READ PA%(I%),PB%(I%),PX%(I%),PY%(I%),PZ%(I%) : NEXT
  360 RESTORE 1430
  370 FOR I%=0 TO NE%-1 : READ EA%(I%),EB%(I%),J%,K% : EM%(I%)=PW%(J%) OR PW%(K%) : NEXT
  380 RESTORE 1520
  390 FOR I%=0 TO NF%-1 : READ NX%(I%),NY%(I%),NZ%(I%) : NEXT
  400 COLOUR 1,0,255,255 : COLOUR 15,255,255,255
  410 DV%=300 : AP%=6 : REM djelitelj mjerila i stalni nagib
  420 COLOUR 15 : PRINT TAB(11,14);"TRENUTAK...";
  430 PROCbox
  440 FOR A%=0 TO NA%-1 : PROCbake(A%) : PRINT TAB(11,16);A%+1;" / ";NA%;" "; : NEXT
  450 A%=0 : FR%=0 : T0%=TIME : F$="" : SP%=2 : TK%=0
  460 REPEAT
  470   VDU 23,0,&A0,BI%+A%;1
  480   PROCinfo
  490   VDU 23,0,&C3
  500   TK%=TK%+1 : IF TK%>=SP% THEN TK%=0 : A%=(A%+1) MOD NA%
  510   PROCkeys
  520 UNTIL Q%
  530 FOR I%=0 TO NA%-1 : VDU 23,0,&A0,BI%+I%;2 : NEXT
  540 VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : PRINT "Bok!" : END
  550 REM ---- projekcija svih 28 vrhova za polozaj A% ----
  560 DEF PROCpoints(A%)
  570 LOCAL I%,J%,K%,X%,Y%,Z%,U%,V%,E%,F%
  580 SY1%=SI%(A%*(64 DIV NA%)) : CY1%=SI%((A%*(64 DIV NA%)+&10) AND &3F)
  590 SP1%=SI%(AP%) : CP1%=SI%((AP%+&10) AND &3F)
  600 M0%=CY1% : M2%=SY1%
  610 M3%=(SP1%*SY1%) DIV &100 : M4%=CP1% : M5%=(-SP1%*CY1%) DIV &100
  620 M6%=(-CP1%*SY1%) DIV &100 : M7%=SP1% : M8%=(CP1%*CY1%) DIV &100
  630 FOR I%=0 TO NC%-1
  640   J%=CI%(I%) : Y%=CY%(I%) : Z%=CZ%(I%)
  650   E%=Z%*M2% : F%=Y%*M4%+Z%*M5%
  660   SX%(J%)=&A0+E% DIV DV% : SY%(J%)=&78-F% DIV DV%
  670 NEXT
  680 FOR I%=0 TO NP%-1
  690   J%=PA%(I%) : K%=PB%(I%)
  700   X%=PX%(I%) : Y%=PY%(I%) : Z%=PZ%(I%)
  710   U%=X%*M0% : V%=X%*M3%
  720   E%=Z%*M2% : F%=Y%*M4%+Z%*M5%
  730   SX%(J%)=&A0+(E%+U%) DIV DV% : SY%(J%)=&78-(F%+V%) DIV DV%
  740   SX%(K%)=&A0+(E%-U%) DIV DV% : SY%(K%)=&78-(F%-V%) DIV DV%
  750 NEXT
  760 ENDPROC
  770 REM ---- pravokutnik u koji brod stane u svim polozajima ----
  780 DEF PROCbox
  790 LOCAL A%,I%
  800 BX0%=319 : BY0%=239 : BX1%=0 : BY1%=0
  810 FOR A%=0 TO NA%-1
  820   PROCpoints(A%)
  830   FOR I%=0 TO 27
  840     IF SX%(I%)<BX0% THEN BX0%=SX%(I%)
  850     IF SX%(I%)>BX1% THEN BX1%=SX%(I%)
  860     IF SY%(I%)<BY0% THEN BY0%=SY%(I%)
  870     IF SY%(I%)>BY1% THEN BY1%=SY%(I%)
  880   NEXT
  890 NEXT
  900 BX0%=BX0%-2 : IF BX0%<0 THEN BX0%=0
  910 BY0%=BY0%-2 : IF BY0%<0 THEN BY0%=0
  920 BX1%=BX1%+2 : IF BX1%>319 THEN BX1%=319
  930 BY1%=BY1%+2 : IF BY1%>239 THEN BY1%=239
  940 ENDPROC
  950 REM ---- ispeci polozaj A% u medjuspremnik ----
  960 DEF PROCbake(A%)
  970 LOCAL I%,N%,VB%
  980 PROCpoints(A%)
  990 VB%=0
 1000 FOR I%=0 TO NF%-1
 1010   IF NX%(I%)*M6%+NY%(I%)*M7%+NZ%(I%)*M8%<0 THEN VB%=VB% OR PW%(I%)
 1020 NEXT
 1030 N%=0
 1040 FOR I%=0 TO NE%-1 : IF (VB% AND EM%(I%)) THEN N%=N%+1
 1050 NEXT
 1060 REM 18 bajta za brisanje i dvije boje, pa 12 po bridu
 1070 VDU 23,0,&A0,BI%+A%;2
 1080 VDU 23,0,&A0,BI%+A%;0,18+N%*12;
 1090 VDU 18,0,0
 1100 VDU 25,4,BX0%;BY0%;
 1110 VDU 25,101,BX1%;BY1%;
 1120 VDU 18,0,1
 1130 FOR I%=0 TO NE%-1
 1140   IF (VB% AND EM%(I%)) THEN VDU 25,4,SX%(EA%(I%));SY%(EA%(I%)); : VDU 25,5,SX%(EB%(I%));SY%(EB%(I%));
 1150 NEXT
 1160 ENDPROC
 1170 REM ---- brojac slicica; 1920 jer TIME ide 20% prebrzo ----
 1180 DEF PROCinfo
 1190 COLOUR 15 : PRINT TAB(0,0);F$;
 1200 FR%=FR%+1
 1210 IF (FR% AND &F)<>0 THEN ENDPROC
 1220 F$=STR$(1920 DIV (TIME-T0%+1))+" fps  "
 1230 T0%=TIME
 1240 ENDPROC
 1250 REM ---- tipke ----
 1260 DEF PROCkeys
 1270 LOCAL K%
 1280 K%=INKEY(0)
 1290 IF K%<0 THEN ENDPROC
 1300 IF K%=32 THEN K%=GET : T0%=TIME : FR%=0 : ENDPROC
 1310 IF K%=43 THEN SP%=SP%-1 : IF SP%<1 THEN SP%=1
 1320 IF K%=45 THEN SP%=SP%+1 : IF SP%>8 THEN SP%=8
 1330 IF (K% AND &DF)=81 THEN Q%=1
 1340 ENDPROC
 1350 REM ---- 4 vrha na osi: indeks, y, z ----
 1360 DATA 2,26,24, 9,26,-40, 20,0,76, 21,0,90
 1370 REM ---- 12 zrcalnih parova ----
 1380 DATA 0,1,32,0,76, 4,3,120,-3,-8, 6,5,88,16,-40
 1390 DATA 7,8,128,-8,-40, 11,10,32,-24,-40, 14,13,8,12,-40
 1400 DATA 15,12,36,8,-40, 16,19,36,-12,-40, 17,18,8,-16,-40
 1410 DATA 25,23,80,6,-40, 26,24,88,0,-40, 27,22,80,-6,-40
 1420 REM ---- 38 bridova: vrh A, vrh B, ploha 1, ploha 2 ----
 1430 DATA 0,1,0,11, 0,4,4,12, 1,3,3,10, 3,8,7,10, 4,7,8,12
 1440 DATA 6,7,8,9, 6,9,6,9, 5,9,5,9, 5,8,7,9, 2,5,1,5
 1450 DATA 2,6,2,6, 3,5,3,7, 4,6,4,8, 1,2,0,1, 0,2,0,2
 1460 DATA 8,10,9,10, 10,11,9,11, 7,11,9,12, 1,10,10,11, 0,11,11,12
 1470 DATA 1,5,1,3, 0,6,2,4, 20,21,0,11, 12,13,9,9, 18,19,9,9
 1480 DATA 14,15,9,9, 16,17,9,9, 15,16,9,9, 14,17,9,9, 13,18,9,9
 1490 DATA 12,19,9,9, 2,9,5,6, 22,24,9,9, 23,24,9,9, 22,23,9,9
 1500 DATA 25,26,9,9, 26,27,9,9, 25,27,9,9
 1510 REM ---- 13 normala ploha ----
 1520 DATA 0,62,31, -18,55,16, 18,55,16, -16,52,14
 1530 DATA 16,52,14, -14,47,0, 14,47,0, -61,102,0
 1540 DATA 61,102,0, 0,0,-80, -7,-42,9, 0,-30,6
 1550 DATA 7,-42,9
