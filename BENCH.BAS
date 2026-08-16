   10 REM Koliko BBC BASIC na Agonu stigne po okviru
   20 MODE 8
   30 VDU 23,0,&C0,0
   40 DIM XV%(31),YV%(31),ZV%(31)
   50 FOR I%=0 TO 27 : XV%(I%)=I%*3-40 : YV%(I%)=I%*2-20 : ZV%(I%)=I%*5-70 : NEXT
   60 M0%=181:M1%=0:M2%=181:M3%=0:M4%=256:M5%=0:M6%=-181:M7%=0:M8%=181
   70 :
   80 REM --- puna rotacija 3x3 + perspektiva, 28 vrhova ---
   90 T%=TIME
  100 FOR F%=1 TO 20
  110   FOR I%=0 TO 27
  120     X%=XV%(I%) : Y%=YV%(I%) : Z%=ZV%(I%)
  130     RX%=(X%*M0%+Y%*M1%+Z%*M2%) DIV 256
  140     RY%=(X%*M3%+Y%*M4%+Z%*M5%) DIV 256
  150     RZ%=(X%*M6%+Y%*M7%+Z%*M8%) DIV 256
  160     SX%=160+(RX%*128) DIV (RZ%+400)
  170     SY%=120-(RY%*128) DIV (RZ%+400)
  180   NEXT
  190 NEXT
  200 A%=TIME-T%
  210 :
  220 REM --- ista stvar, jedna os i bez perspektive ---
  230 T%=TIME
  240 FOR F%=1 TO 20
  250   FOR I%=0 TO 27
  260     X%=XV%(I%) : Z%=ZV%(I%)
  270     SX%=160+(X%*M0%+Z%*M2%) DIV 256
  280     SY%=120-YV%(I%)
  290   NEXT
  300 NEXT
  310 B%=TIME-T%
  320 :
  330 REM --- crtanje 38 bridova ---
  340 T%=TIME
  350 FOR F%=1 TO 20
  360   FOR I%=1 TO 38
  370     MOVE 100,100 : DRAW 200,150
  380   NEXT
  390 NEXT
  400 C%=TIME-T%
  410 :
  420 REM --- samo citanje iz gotove tablice ---
  430 T%=TIME
  440 FOR F%=1 TO 20
  450   FOR I%=0 TO 27
  460     SX%=XV%(I%) : SY%=YV%(I%)
  470   NEXT
  480 NEXT
  490 D%=TIME-T%
  500 :
  510 MODE 1
  520 PRINT "20 okvira, 28 vrhova, sve u centisekundama"
  530 PRINT "puna 3x3 rotacija + perspektiva : ";A%
  540 PRINT "jedna os, bez perspektive       : ";B%
  550 PRINT "38 bridova MOVE+DRAW            : ";C%
  560 PRINT "citanje gotove tablice          : ";D%
  570 PRINT
  580 PRINT "po okviru (cs): ";A%/20;" ";B%/20;" ";C%/20;" ";D%/20
  590 END
