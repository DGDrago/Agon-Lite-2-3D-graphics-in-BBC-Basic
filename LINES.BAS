   10 REM Koliko linija u sekundi moze Agon
   20 REM  a) obicni MOVE+DRAW iz BASIC-a  - granica je eZ80
   30 REM  b) gotov niz VDU naredbi kroz PRINT - granica je veza
   40 REM     prema VDP-u i sam VDP
   50 MODE 8
   60 VDU 23,0,&C0,0 : REM piksel koordinate
   70 VDU 23,1,0
   80 GCOL 0,15
   90 N%=2000
  100 T%=TIME
  110 FOR I%=1 TO N% : MOVE 20,20 : DRAW 300,220 : NEXT
  120 A%=TIME-T%
  130 REM --- slozi blok od 20 linija kao sirove VDU bajtove ---
  140 L$=""
  150 FOR I%=0 TO 19
  160   X%=20+I%*14 : Y%=20+I%*10 : P%=300-X% : Q%=220-Y%
  170   L$=L$+CHR$(25)+CHR$(4)+CHR$(X% AND 255)+CHR$(X% DIV 256)+CHR$(Y% AND 255)+CHR$(Y% DIV 256)
  180   L$=L$+CHR$(25)+CHR$(5)+CHR$(P% AND 255)+CHR$(P% DIV 256)+CHR$(Q% AND 255)+CHR$(Q% DIV 256)
  190 NEXT
  200 M%=500
  210 T%=TIME
  220 FOR I%=1 TO M% : PRINT L$; : NEXT
  230 B%=TIME-T%
  240 REM --- prazna petlja za usporedbu ---
  250 T%=TIME
  260 FOR I%=1 TO M% : NEXT
  270 C%=TIME-T%
  280 MODE 1
  290 PRINT "a) MOVE+DRAW iz BASIC-a"
  300 PRINT "   ";N%;" linija u ";A%;" cs"
  310 IF A%>0 THEN PRINT "   ";N%*100 DIV A%;" linija u sekundi"
  320 PRINT
  330 PRINT "b) gotovi VDU bajtovi kroz PRINT"
  340 PRINT "   ";M%*20;" linija u ";B%-C%;" cs"
  350 IF B%-C%>0 THEN PRINT "   ";M%*2000 DIV (B%-C%);" linija u sekundi"
  360 PRINT
  370 PRINT "duljina bloka: ";LEN(L$);" bajta za 20 linija"
  380 END
