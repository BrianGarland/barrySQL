
       Ctl-Opt DFTACTGRP(*No);
       
      /copy 'headers.rpgle'
       
       Dcl-Pi BARRYSQL;
         gIFS Char(128);
       End-Pi;
       
       Dcl-Ds gInputFile LikeDS(File_Temp);
       Dcl-Ds gOutFile   LikeDS(File_Temp);
       Dcl-Ds gSQLLine Qualified;
         Data   Varchar(2048);
         SQL    Varchar(2048);
         Pieces Varchar(32) Dim(10);
       End-Ds;
       
       Dcl-S gCurrentSQLStmt Int(3) Inz(0);
       
       DSPLY ('barrySQL started.');
       
       gInputFile.PathFile = %TrimR(gIFS) + x'00';
       gInputFile.OpenMode = 'r' + x'00';
       gInputFile.FilePtr  = OpenFile(%addr(gInputFile.PathFile)
                                     :%addr(gInputFile.OpenMode));
                                     
       If (gInputFile.FilePtr <> *Null);
         BarrySQL_CreateTemp();
       
         dow (ReadFile(%addr(gInputFile.RtvData)
              :%Len(gInputFile.RtvData)
              :gInputFile.FilePtr) <> *null);
              
           If (%Subst(gInputFile.RtvData:1:1) = x'25');
             Iter;
           ENDIF;
           
           gInputFile.RtvData = 
             %xlate(x'00' + x'25' + x'0D' + x'05':'    ':gInputFile.RtvData);
           
           gSQLLine.Data = %Trim(gInputFile.RtvData);
           If (%Subst(gSQLLine.Data:1:8) = 'EXEC SQL');
             gSQLLine.SQL = %Subst(gSQLLine.Data:10);
             BarrySQL_Parse();
           Else;
             BarrySQL_WriteTemp(gInputFile.RtvData);
           Endif;
         Enddo;
         
         CloseFile(gInputFile.FilePtr);
         BarrySQL_CloseTemp();
         
       Else;
         DSPLY ('Unable to open file.');
       Endif;
       
       DSPLY ('Program end');
       
       *InLR = *On;
       Return;
       
       //*********************************
       
       Dcl-Proc BarrySQL_CreatePieces;
         Dcl-S lIndex    Int(5);
         Dcl-S lCur      Int(5);
         Dcl-S lCurPiece Varchar(32);
         Dcl-S lCurChar  Char(1);
         
         Clear gSQLLine.Pieces;
         lCur = 1;
         lCurPiece = '';
         For lIndex = 1 to %Len(gSQLLine.SQL);
           If (lCur > %Elem(gSQLLine.Pieces));
             Leave;
           Endif;
           
           lCurChar = %Subst(gSQLLine.SQL:lIndex:1);
           If (lCurChar = ' ');
             gSQLLine.Pieces(lCur) = lCurPiece;
             lCurPiece = '';
             lCur += 1;
           Else;
             lCurPiece += lCurChar;
           Endif;
           
         Endfor;
         
         If (lCurPiece <> '');
           gSQLLine.Pieces(lCur) = lCurPiece;
         Endif;
       End-Proc;
       
       //************************************
       
       Dcl-Proc BarrySQL_Parse;
         BarrySQL_CreatePieces();
         
         Select;
           When (gSQLLine.Pieces(1) = 'DEFINE');
             If (gSQLLine.Pieces(2) = 'DS');
               BarrySQL_WriteTemp('        Dcl-S env Int(10);');
               BarrySQL_WriteTemp('        Dcl-S hdl Int(10);');
               BarrySQL_WriteTemp('        Dcl-S stmt Int(10) Dim(10) Inz(0);');
               DSPLY ('Defining special DS');
             Endif;
             If (gSQLLine.Pieces(2) = 'HEADERS');
               BarrySQL_WriteTemp('       /COPY ''SQLCLI.h''');
             Endif;
           When (gSQLLine.Pieces(1) = 'CONNECT');
             BarrySQL_WriteTemp('        SQLAllocEnv(%Addr(env));');
             BarrySQL_WriteTemp('        SQLAllocConnect(env:%Addr(hdl));');
             BarrySQL_WriteTemp('        SQLConnect(hdl:'     
                               + '''' + gSQLLine.Pieces(2) + '''' + 
                               ':SQL_NTS:0:SQL_NTS:0:SQL_NTS);');
             DSPLY ('Connect found');
           When (gSQLLine.Pieces(1) = 'SELECT');
             gCurrentSQLStmt += 1;
             BarrySQL_WriteTemp('        SQLAllocStmt(hdl' + 
                                ':%Addr(stmt(' + %Char(gCurrentSQLStmt)
                                 + ')));');
             BarrySQL_WriteTemp('        SQLExecDirect(' + 
                                'stmt(' + %Char(gCurrentSQLStmt) + '):' +
                                '''' + gSQLLine.SQL + ''':SQL_NTS);');
             DSPLY ('Select statement found');
           When (gSQLLine.Pieces(1) = 'FETCH');
             BarrySQL_WriteTemp('        //DOING FETCH!!');
             DSPLY ('Fetch found');
           When (gSQLLine.Pieces(1) = 'CLOSE');
             BarrySQL_WriteTemp('        //DOING CLOSE!!');
             DSPLY ('Close found');
           When (gSQLLine.Pieces(1) = 'DISCONNECT');
             BarrySQL_WriteTemp('        //DOING DISCONNECT!!');
             DSPLY ('Disconnect found');
         Endsl;
       End-Proc;
       
       //************************************
       
       Dcl-Proc BarrySQL_CreateTemp;
         gOutFile.PathFile = %Trim(gIFS) + '.brysql' + x'00';
         gOutFile.OpenMode = 'w' + x'00';
         gOutFile.FilePtr  = OpenFile(%addr(gOutFile.PathFile)
                                     :%addr(gOutFile.OpenMode));
       End-Proc;
       
       Dcl-Proc BarrySQL_WriteTemp;
         Dcl-Pi *N;
           pValue Char(132) Value;
         END-PI;
         
         pValue = %TrimR(pValue) + x'25';
         WriteFile(%Addr(pValue)
                  :%Len(%TrimR(pValue))
                  :1
                  :gOutFile.FilePtr);
       End-Proc;
       
       Dcl-Proc BarrySQL_CloseTemp;
         CloseFile(gOutFile.FilePtr);
       End-Proc;