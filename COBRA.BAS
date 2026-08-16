   10 REM ---------------------------------------------------------
   20 REM  Cobra MkIII - rotirajuci zicani model u realnom vremenu
   30 REM  Agon Light 2, cisti BBC BASIC, bez asemblera
   40 REM  28 vrhova, 38 bridova, 13 ploha - izvorna Elite
   50 REM  MODE 136 = 320x240, 64 boje, dvostruki spremnik
   60 REM
   70 REM  Sto je napravljeno za brzinu, po velicini dobitka:
   80 REM   1. simetrija - 4 vrha na osi, 12 zrcalnih parova; za par
   90 REM      se zajednicki dio racuna jednom, 8 mnozenja umjesto 16
  100 REM   2. ortografska projekcija - nema z ni dubinske diobe,
  110 REM      mjerilo je uklopljeno u isto dijeljenje (tipka O)
  120 REM   3. vidljivost ploha kao bitovna maska - jedno citanje
  130 REM      polja po bridu umjesto cetiri
  140 REM   4. PROCortho je raspetljan: nema petlje ni polja s
  150 REM      koordinatama, sve su konstante upisane u kod
  160 REM   5. sve konstante su heksadekadske - izmjereno je da ih
  170 REM      BBC BASIC cita jednako brzo kao varijable, a
  180 REM      dekadske pretvara iz teksta pri svakom izvodjenju
  190 REM
  200 REM  Tipke: Q kraj, SPACE pauza, H skrivanje, O perspektiva,
  210 REM         + / - blize i dalje
  220 REM ---------------------------------------------------------
  230 MODE 136
  240 VDU 23,0,&C0,0 : REM piksel koordinate, ishodiste gore lijevo
  250 VDU 23,1,0
  260 ON ERROR VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : REPORT : PRINT " u liniji ";ERL : END
  270 NC%=4 : NP%=12 : NE%=38 : NF%=13
  280 DIM SX%(27),SY%(27),SI%(63),PW%(12),EM%(37)
  290 DIM EA%(37),EB%(37),NX%(12),NY%(12),NZ%(12)
  300 DIM CI%(3),CY%(3),CZ%(3),PA%(11),PB%(11),PX%(11),PY%(11),PZ%(11)
  310 FOR I%=0 TO 63 : SI%(I%)=INT(256*SIN(I%*PI/32)+0.5) : NEXT
  320 PW%(0)=1 : FOR I%=1 TO 12 : PW%(I%)=PW%(I%-1)*2 : NEXT
  330 RESTORE 1740
  340 FOR I%=0 TO NC%-1 : READ CI%(I%),CY%(I%),CZ%(I%) : NEXT
  350 RESTORE 1760
  360 FOR I%=0 TO NP%-1 : READ PA%(I%),PB%(I%),PX%(I%),PY%(I%),PZ%(I%) : NEXT
  370 RESTORE 1810
  380 FOR I%=0 TO NE%-1 : READ EA%(I%),EB%(I%),J%,K% : EM%(I%)=PW%(J%) OR PW%(K%) : NEXT
  390 RESTORE 1900
  400 FOR I%=0 TO NF%-1 : READ NX%(I%),NY%(I%),NZ%(I%) : NEXT
  410 COLOUR 1,0,255,255 : COLOUR 15,255,255,255
  420 DV%=310 : DS%=420 : SC%=340 : HD%=1 : PR%=0
  430 AY%=32 : AP%=0 : FR%=0 : T0%=TIME : F$=""
  440 REPEAT
  450   PROCframe
  460   AY%=(AY%+1) AND &3F
  470   IF (FR% MOD 3)=0 THEN AP%=(AP%+1) AND &3F
  480   PROCkeys
  490 UNTIL Q%
  500 VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : PRINT "Bok!" : END
  510 REM ---- jedan okvir ----
  520 DEF PROCframe
  530 SY1%=SI%(AY%) : CY1%=SI%((AY%+&10) AND &3F)
  540 SP1%=SI%(AP%) : CP1%=SI%((AP%+&10) AND &3F)
  550 REM matrica Rx(nagib) * Ry(zaokret); clan m01 je nula
  560 M0%=CY1% : M2%=SY1%
  570 M3%=(SP1%*SY1%) DIV &100 : M4%=CP1% : M5%=(-SP1%*CY1%) DIV &100
  580 M6%=(-CP1%*SY1%) DIV &100 : M7%=SP1% : M8%=(CP1%*CY1%) DIV &100
  590 IF PR% THEN PROCpersp ELSE PROCortho
  600 REM ploha gleda prema nama ako joj je z zarotirane normale
  610 REM negativan; bitovi vidljivih ploha idu u masku VB%
  620 VB%=0
  630 FOR I%=0 TO NF%-1
  640   IF NX%(I%)*M6%+NY%(I%)*M7%+NZ%(I%)*M8%<0 THEN VB%=VB% OR PW%(I%)
  650 NEXT
  660 GCOL 0,0 : MOVE 0,0 : PLOT 101,319,239
  670 GCOL 0,1
  680 FOR I%=0 TO NE%-1
  690   IF HD%=0 OR (VB% AND EM%(I%)) THEN MOVE SX%(EA%(I%)),SY%(EA%(I%)) : DRAW SX%(EB%(I%)),SY%(EB%(I%))
  700 NEXT
  710 PROCinfo
  720 VDU 23,0,&C3 : REM zamijeni spremnike
  730 ENDPROC
  740 REM ---- brzi put: raspetljano, bez polja i bez petlje ----
  750 DEF PROCortho
  760 E%=&18*M2% : F%=&1A*M4%+&18*M5%
  770 SX%(&2)=&A0+E% DIV DV% : SY%(&2)=&78-F% DIV DV%
  780 E%=-&28*M2% : F%=&1A*M4%-&28*M5%
  790 SX%(&9)=&A0+E% DIV DV% : SY%(&9)=&78-F% DIV DV%
  800 E%=&4C*M2% : F%=&4C*M5%
  810 SX%(&14)=&A0+E% DIV DV% : SY%(&14)=&78-F% DIV DV%
  820 E%=&5A*M2% : F%=&5A*M5%
  830 SX%(&15)=&A0+E% DIV DV% : SY%(&15)=&78-F% DIV DV%
  840 A%=&20*M0% : B%=&20*M3%
  850 E%=&4C*M2% : F%=&4C*M5%
  860 SX%(&0)=&A0+(E%+A%) DIV DV% : SY%(&0)=&78-(F%+B%) DIV DV%
  870 SX%(&1)=&A0+(E%-A%) DIV DV% : SY%(&1)=&78-(F%-B%) DIV DV%
  880 A%=&78*M0% : B%=&78*M3%
  890 E%=-&8*M2% : F%=-&3*M4%-&8*M5%
  900 SX%(&4)=&A0+(E%+A%) DIV DV% : SY%(&4)=&78-(F%+B%) DIV DV%
  910 SX%(&3)=&A0+(E%-A%) DIV DV% : SY%(&3)=&78-(F%-B%) DIV DV%
  920 A%=&58*M0% : B%=&58*M3%
  930 E%=-&28*M2% : F%=&10*M4%-&28*M5%
  940 SX%(&6)=&A0+(E%+A%) DIV DV% : SY%(&6)=&78-(F%+B%) DIV DV%
  950 SX%(&5)=&A0+(E%-A%) DIV DV% : SY%(&5)=&78-(F%-B%) DIV DV%
  960 A%=&80*M0% : B%=&80*M3%
  970 E%=-&28*M2% : F%=-&8*M4%-&28*M5%
  980 SX%(&7)=&A0+(E%+A%) DIV DV% : SY%(&7)=&78-(F%+B%) DIV DV%
  990 SX%(&8)=&A0+(E%-A%) DIV DV% : SY%(&8)=&78-(F%-B%) DIV DV%
 1000 A%=&20*M0% : B%=&20*M3%
 1010 E%=-&28*M2% : F%=-&18*M4%-&28*M5%
 1020 SX%(&B)=&A0+(E%+A%) DIV DV% : SY%(&B)=&78-(F%+B%) DIV DV%
 1030 SX%(&A)=&A0+(E%-A%) DIV DV% : SY%(&A)=&78-(F%-B%) DIV DV%
 1040 A%=&8*M0% : B%=&8*M3%
 1050 E%=-&28*M2% : F%=&C*M4%-&28*M5%
 1060 SX%(&E)=&A0+(E%+A%) DIV DV% : SY%(&E)=&78-(F%+B%) DIV DV%
 1070 SX%(&D)=&A0+(E%-A%) DIV DV% : SY%(&D)=&78-(F%-B%) DIV DV%
 1080 A%=&24*M0% : B%=&24*M3%
 1090 E%=-&28*M2% : F%=&8*M4%-&28*M5%
 1100 SX%(&F)=&A0+(E%+A%) DIV DV% : SY%(&F)=&78-(F%+B%) DIV DV%
 1110 SX%(&C)=&A0+(E%-A%) DIV DV% : SY%(&C)=&78-(F%-B%) DIV DV%
 1120 A%=&24*M0% : B%=&24*M3%
 1130 E%=-&28*M2% : F%=-&C*M4%-&28*M5%
 1140 SX%(&10)=&A0+(E%+A%) DIV DV% : SY%(&10)=&78-(F%+B%) DIV DV%
 1150 SX%(&13)=&A0+(E%-A%) DIV DV% : SY%(&13)=&78-(F%-B%) DIV DV%
 1160 A%=&8*M0% : B%=&8*M3%
 1170 E%=-&28*M2% : F%=-&10*M4%-&28*M5%
 1180 SX%(&11)=&A0+(E%+A%) DIV DV% : SY%(&11)=&78-(F%+B%) DIV DV%
 1190 SX%(&12)=&A0+(E%-A%) DIV DV% : SY%(&12)=&78-(F%-B%) DIV DV%
 1200 A%=&50*M0% : B%=&50*M3%
 1210 E%=-&28*M2% : F%=&6*M4%-&28*M5%
 1220 SX%(&19)=&A0+(E%+A%) DIV DV% : SY%(&19)=&78-(F%+B%) DIV DV%
 1230 SX%(&17)=&A0+(E%-A%) DIV DV% : SY%(&17)=&78-(F%-B%) DIV DV%
 1240 A%=&58*M0% : B%=&58*M3%
 1250 E%=-&28*M2% : F%=-&28*M5%
 1260 SX%(&1A)=&A0+(E%+A%) DIV DV% : SY%(&1A)=&78-(F%+B%) DIV DV%
 1270 SX%(&18)=&A0+(E%-A%) DIV DV% : SY%(&18)=&78-(F%-B%) DIV DV%
 1280 A%=&50*M0% : B%=&50*M3%
 1290 E%=-&28*M2% : F%=-&6*M4%-&28*M5%
 1300 SX%(&1B)=&A0+(E%+A%) DIV DV% : SY%(&1B)=&78-(F%+B%) DIV DV%
 1310 SX%(&16)=&A0+(E%-A%) DIV DV% : SY%(&16)=&78-(F%-B%) DIV DV%
 1320 ENDPROC
 1330 REM ---- spori put: prava perspektiva, za usporedbu ----
 1340 DEF PROCpersp
 1350 FOR I%=0 TO NC%-1
 1360   J%=CI%(I%) : Y%=CY%(I%) : Z%=CZ%(I%)
 1370   RX%=(Z%*M2%) DIV &100 : RY%=(Y%*M4%+Z%*M5%) DIV &100
 1380   D%=(Y%*M7%+Z%*M8%) DIV &100+DS%
 1390   SX%(J%)=&A0+(RX%*SC%) DIV D% : SY%(J%)=&78-(RY%*SC%) DIV D%
 1400 NEXT
 1410 FOR I%=0 TO NP%-1
 1420   J%=PA%(I%) : K%=PB%(I%)
 1430   X%=PX%(I%) : Y%=PY%(I%) : Z%=PZ%(I%)
 1440   A%=X%*M0% : B%=X%*M3% : C%=X%*M6%
 1450   E%=Z%*M2% : F%=Y%*M4%+Z%*M5% : G%=Y%*M7%+Z%*M8%
 1460   RX%=(E%+A%) DIV &100 : RY%=(F%+B%) DIV &100 : D%=(G%+C%) DIV &100+DS%
 1470   SX%(J%)=&A0+(RX%*SC%) DIV D% : SY%(J%)=&78-(RY%*SC%) DIV D%
 1480   RX%=(E%-A%) DIV &100 : RY%=(F%-B%) DIV &100 : D%=(G%-C%) DIV &100+DS%
 1490   SX%(K%)=&A0+(RX%*SC%) DIV D% : SY%(K%)=&78-(RY%*SC%) DIV D%
 1500 NEXT
 1510 ENDPROC
 1520 REM ---- brojac slicica, mjeri se svakih 16 okvira ----
 1530 DEF PROCinfo
 1540 COLOUR 15 : PRINT TAB(0,0);F$;
 1550 FR%=FR%+1
 1560 IF (FR% AND &F)<>0 THEN ENDPROC
 1570 F$=STR$(1600 DIV (TIME-T0%+1))+" fps"
 1580 T0%=TIME
 1590 ENDPROC
 1600 REM ---- tipke ----
 1610 DEF PROCkeys
 1620 LOCAL K%
 1630 K%=INKEY(0)
 1640 IF K%<0 THEN ENDPROC
 1650 IF K%=32 THEN K%=GET : T0%=TIME : FR%=0 : ENDPROC
 1660 IF K%=43 THEN DV%=DV%-20 : DS%=DS%-40 : IF DV%<120 THEN DV%=120
 1670 IF K%=45 THEN DV%=DV%+20 : DS%=DS%+40 : IF DV%>900 THEN DV%=900
 1680 K%=K% AND &DF
 1690 IF K%=72 THEN HD%=1-HD%
 1700 IF K%=79 THEN PR%=1-PR% : T0%=TIME : FR%=0
 1710 IF K%=81 THEN Q%=1
 1720 ENDPROC
 1730 REM ---- 4 vrha na osi: indeks, y, z ----
 1740 DATA 2,26,24, 9,26,-40, 20,0,76, 21,0,90
 1750 REM ---- 12 zrcalnih parova: indeks+, indeks-, x, y, z ----
 1760 DATA 0,1,32,0,76, 4,3,120,-3,-8, 6,5,88,16,-40
 1770 DATA 7,8,128,-8,-40, 11,10,32,-24,-40, 14,13,8,12,-40
 1780 DATA 15,12,36,8,-40, 16,19,36,-12,-40, 17,18,8,-16,-40
 1790 DATA 25,23,80,6,-40, 26,24,88,0,-40, 27,22,80,-6,-40
 1800 REM ---- 38 bridova: vrh A, vrh B, ploha 1, ploha 2 ----
 1810 DATA 0,1,0,11, 0,4,4,12, 1,3,3,10, 3,8,7,10, 4,7,8,12
 1820 DATA 6,7,8,9, 6,9,6,9, 5,9,5,9, 5,8,7,9, 2,5,1,5
 1830 DATA 2,6,2,6, 3,5,3,7, 4,6,4,8, 1,2,0,1, 0,2,0,2
 1840 DATA 8,10,9,10, 10,11,9,11, 7,11,9,12, 1,10,10,11, 0,11,11,12
 1850 DATA 1,5,1,3, 0,6,2,4, 20,21,0,11, 12,13,9,9, 18,19,9,9
 1860 DATA 14,15,9,9, 16,17,9,9, 15,16,9,9, 14,17,9,9, 13,18,9,9
 1870 DATA 12,19,9,9, 2,9,5,6, 22,24,9,9, 23,24,9,9, 22,23,9,9
 1880 DATA 25,26,9,9, 26,27,9,9, 25,27,9,9
 1890 REM ---- 13 normala ploha: x, y, z ----
 1900 DATA 0,62,31, -18,55,16, 18,55,16, -16,52,14
 1910 DATA 16,52,14, -14,47,0, 14,47,0, -61,102,0
 1920 DATA 61,102,0, 0,0,-80, -7,-42,9, 0,-30,6
 1930 DATA 7,-42,9
