   10 REM ---------------------------------------------------------
   20 REM  Cobra MkIII - 64 x 1 pre-baked orientations
   30 REM  Agon Light 2, pure BBC BASIC, no assembler
   40 REM
   50 REM  Reads COBRA_64x1.VDU (16 KB) and drops each orientation
   60 REM  straight into a VDP buffer. A frame then costs six bytes:
   70 REM      VDU 23,0,&A0,id;1
   80 REM  Neither the geometry nor the drawing touches the eZ80, so
   90 REM  the frame rate is limited by VSYNC alone.
  100 REM
  110 REM  The file is read with INPUT#, which returns raw bytes up
  120 REM  to a CR - 200 bytes per BASIC statement instead of one.
  130 REM  bake.py guarantees byte 13 never occurs inside a payload.
  140 REM
  150 REM  Everything happens in MODE 136 so the buffers are never
  160 REM  exposed to a mode change; progress is printed into both
  170 REM  screen buffers so it stays readable while loading.
  180 REM
  190 REM  Rotation: one axis, fixed tilt.
  200 REM  Keys: Q quit, SPACE pause
  210 REM ---------------------------------------------------------
  220 NY%=64 : NT%=1 : NPOS%=64 : BI%=&2000
  230 D$="COBRA_64x1.VDU"
  240 MODE 136
  250 VDU 23,0,&C0,0 : REM pixel coordinates, origin top left
  260 VDU 23,1,0
  270 ON ERROR VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : REPORT : PRINT " at line ";ERL : END
  280 COLOUR 15
  290 CLS : VDU 23,0,&C3 : CLS : VDU 23,0,&C3
  300 P$="loading "+D$ : PROCsay(12,P$)
  310 PROCload
  320 AA%=0 : PP%=0 : FR%=0 : T0%=TIME : F$="" : TK%=0 : PS%=3
  330 CLS : VDU 23,0,&C3 : CLS : VDU 23,0,&C3
  340 REPEAT
  350   VDU 23,0,&A0,BI%+PP%*NY%+AA%;1
  360   PROCinfo
  370   VDU 23,0,&C3
  380   AA%=(AA%+1) MOD NY%
  390   PROCkeys
  400 UNTIL Q%
  410 FOR I%=0 TO NPOS%-1 : VDU 23,0,&A0,BI%+I%;2 : NEXT
  420 VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : PRINT "Bye!" : END
  430 REM ---- stream the file into VDP buffers ----
  440 DEF PROCload
  450 LOCAL G%,N%,C%,L%,A$
  460 G%=OPENIN(D$)
  470 IF G%=0 THEN VDU 23,1,1 : VDU 23,0,&C0,1 : MODE 1 : PRINT "missing ";D$ : END
  480 FOR N%=0 TO NPOS%-1
  490   INPUT#G%,A$ : L%=VAL(A$)
  500   VDU 23,0,&A0,BI%+N%;2
  510   VDU 23,0,&A0,BI%+N%;0,L%;
  520   FOR C%=1 TO (L%+199) DIV 200
  530     INPUT#G%,A$ : PRINT A$;
  540   NEXT
  550   IF (N% AND &1F)=0 THEN PROCsay(14,STR$(N%)+" / "+STR$(NPOS%)+"   ")
  560 NEXT
  570 CLOSE#G%
  580 ENDPROC
  590 REM ---- print into both screen buffers so it stays visible ----
  600 DEF PROCsay(R%,S$)
  610 PRINT TAB(6,R%);S$;
  620 VDU 23,0,&C3
  630 PRINT TAB(6,R%);S$;
  640 VDU 23,0,&C3
  650 ENDPROC
  660 REM ---- frame counter; 1920 because TIME runs 20% fast at 60Hz ----
  670 DEF PROCinfo
  680 PRINT TAB(0,0);F$;
  690 FR%=FR%+1
  700 IF (FR% AND &F)<>0 THEN ENDPROC
  710 F$=STR$(1920 DIV (TIME-T0%+1))+" fps  "
  720 T0%=TIME
  730 ENDPROC
  740 REM ---- keys ----
  750 DEF PROCkeys
  760 LOCAL K%
  770 K%=INKEY(0)
  780 IF K%<0 THEN ENDPROC
  790 IF K%=32 THEN K%=GET : T0%=TIME : FR%=0 : ENDPROC
  800 IF (K% AND &DF)=81 THEN Q%=1
  810 ENDPROC
