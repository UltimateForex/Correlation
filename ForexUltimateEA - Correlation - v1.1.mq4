#import "kernel32.dll"
   bool CopyFileW(string lpExistingFileName, string lpNewFileName,
bool failIfExists);
   int GetLastError(void);
#import

#include "..\include\stdlib.mqh";

#property description   "Correlation"
#property copyright     "Copyright 2015, MetaQuotes Software Corp."
#property link          "https://www.mql5.com"
#property version       "1.1"
#property strict

int            MagicNumber             = 3151818;
bool           Executando              = false;
datetime       DataHoraUtimaGeracao    = 0;
double         TamLotePorMil           = MarketInfo(Symbol(),MODE_LOTSIZE)/1000.0 ; //micro=1, std=100
int            TimeFrameCorrelation    = PERIOD_D1;
int            TimeFrameTrading        = 0;
double         CORRELACAO_MINIMA       = 0.70;
double         PERCENTUAL_TRADE        = 0.05;

struct pair
{
   string   Ativo;
   color    Cor;
   double   Corr;
};

pair Pair[];

string Ativos[];  

int OnInit()
{
   ObjectsDeleteAll(0);
   LoadSymbols();
   Main();
   EventSetTimer(Period());
   return(INIT_SUCCEEDED);
}

void OnTimer()
{
   Main();
}

void Main()
{
   if (Executando) return;
   Executando = true;
   GetCurrentCorrelatedPairs();
   for (int i=0; i<ArraySize(Pair); i++)
   {
      if (Pair[i].Ativo!=Symbol())
         CreateChart(i);  
      Sleep(150);
   }   
   Executando=false;
}

void GetCurrentCorrelatedPairs()
{
   int j=0;
   string curr1 = StringSubstr(Symbol(), 0, 3);
   string curr2 = StringSubstr(Symbol(), 3, 3);
   for (int i=0; i<ArraySize(Ativos); i++)
   {
      string curr3 = StringSubstr(Ativos[i], 0, 3);
      string curr4 = StringSubstr(Ativos[i], 3, 3);
      if (curr1==curr3 || curr1==curr4 || curr2==curr3 || curr2==curr4)
      {
         double FatorPreco = 0;
         double Corr = Correlation(Symbol(), Ativos[i], FatorPreco, 0);
         if (Corr>CORRELACAO_MINIMA)
         {
            ArrayResize(Pair,j+1);
            Pair[j].Ativo = Ativos[i];
            Pair[j].Corr = Corr;
            int r = 0, g = 0, b = 0;
            while (r<64 && g<64 && b<64)
            {
               r = (int)((double)255*MathRand()/32767.0);
               g = (int)((double)255*MathRand()/32767.0);
               b = (int)((double)255*MathRand()/32767.0);
            }
            Pair[j].Cor = (color)RGB(r,g,b);
            j++;
         }
      }
   }
   Label("status2", "Correlated Pairs: " + IntegerToString(ArraySize(Pair)-1), 0, 0.1, clrGreen, 20, true, false);
}

double Correlation(string symbol1, string symbol2, double &FatorPrecoMedio, int shift)
{
   int limit = 90;
   int Length = 90;
   int i, j, r;
   double result   = 0;
   double pBuffer[][2]; //0=symbol1, 1=symbol2
   if (ArrayRange(pBuffer,0) != Bars) ArrayResize(pBuffer,Bars);
   
   //calculo das medias dos ultimos 90 dias
   //for (i=0; i<limit; i++)
   //{
   i = shift;
   double soma0=0, soma1=0;
   for (j=i; j<i+limit; j++)
   {
      soma0 += iMA(symbol1,TimeFrameCorrelation,1,0,MODE_SMA,PRICE_CLOSE,j+shift);
      soma1 += iMA(symbol2,TimeFrameCorrelation,1,0,MODE_SMA,PRICE_CLOSE,j+shift);
   }
   if (soma1!=0)
      FatorPrecoMedio = soma0/soma1;
   else
      FatorPrecoMedio = 0;
   //}

   //////////////////////////////////////////////////////////////////////
   //
   // Calculo da correlacao
   //
   // limit=30, len=30, bars=90
   // 987654321|987654321|9876543210|987654321|987654321|987654321|987654321|987654321|9876543210
   //
   // i=30, r=59
   // pBuffer[59]=iMA(30)
   // k=0 --> k<30
   // pricea = pBuffer[59-0], pricea = pBuffer[59-1]... pricea = pBuffer[59-29=30]
   //
   // i=29, r=60
   // pBuffer[60]=iMA(29)
   // k=0 --> k<30
   // pricea = pBuffer[60-0], pricea = pBuffer[60-1]... pricea = pBuffer[60-29=31]
   //
   // i=28, r=61
   // pBuffer[61]=iMA(28)
   // k=0 --> k<30
   // pricea = pBuffer[61-0], pricea = pBuffer[61-1]... pricea = pBuffer[61-29=32]
   // ...
   // i=0, r=89
   // pBuffer[89]=iMA(0)
   // k=0 --> k<30
   // pricea = pBuffer[89-0], pricea = pBuffer[89-1]... pricea = pBuffer[89-29=60]
   //
   //
   //
   //
   for(i=limit, r=Bars-limit-1; i>=0; i--,r++) //ex: bars=1000 --> r=809 to 899, i=90 to 0
   {
      pBuffer[r][0] = iMA(symbol1,TimeFrameCorrelation,1,0,MODE_SMA,PRICE_CLOSE,i+shift);
      pBuffer[r][1] = iMA(symbol2,TimeFrameCorrelation,1,0,MODE_SMA,PRICE_CLOSE,i+shift);
      double sx  = 0;
      double sy  = 0;
      double sxy = 0;
      double sx2 = 0;
      double sy2 = 0;
      for (int k=0; k<Length; k++)
      {
         double pricea = pBuffer[r-k][0]; //ex: r-k=809-90
         double priceb = pBuffer[r-k][1];
            sx += pricea; sx2 += pricea*pricea;
            sy += priceb; sy2 += priceb*priceb;
                          sxy += pricea*priceb;
      }
      double dividend = MathSqrt(((sx2-(sx*sx)/Length)*(sy2-(sy*sy)/Length)));
         if (dividend != 0)
                  result = (sxy - (sx*sy)/Length)/dividend;
   }
   return result;
}

void CreateChart(int i)
{
   RefreshRates();
   int QtdBarras  = 300;
   int Counter    = QtdBarras-1;
   double Preco0=0, Preco1=0, Preco1Ant=0;
   
   int CHART_HEIGHT = (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   double AlturaPorMoeda = (double)CHART_HEIGHT / ArraySize(Pair);
   int y1 = (int)(i * AlturaPorMoeda);
   int x0,y0,sub;

   datetime time1;
   double   preco0_real = iClose(Symbol(),TimeFrameTrading,1);
   double   price1_real = iClose(Pair[i].Ativo,TimeFrameTrading,1);
   double   price1_virtual;
   ChartTimePriceToXY(0,0,TimeCurrent(),preco0_real,x0,y0); //obtem o x e y do ativo corrente no candle 0
   ChartXYToTimePrice(0,x0,y1,sub,time1,price1_virtual);
   double   FatorPrecoVirtual = 0;
   if (price1_real!=0) FatorPrecoVirtual = price1_virtual / price1_real;
   double   Dif = price1_virtual - preco0_real;
   
   while(Counter>0)
   {
      Sleep(1);
      
      Preco0 = (iClose(Symbol(),TimeFrameTrading,Counter-1));// - Dif;
      Preco1 = (iClose(Pair[i].Ativo,TimeFrameTrading,Counter-1));// - Dif;
      Preco1Ant = (iClose(Pair[i].Ativo,TimeFrameTrading,Counter)); //- Dif;

      double FatorPrecoMedio = 0;
      double Corr = Correlation(Symbol(), Ativos[i], FatorPrecoMedio, Counter);

      double FatorPrecoAtual = 0;
      if (Preco1!=0)
         FatorPrecoAtual = Preco0 /Preco1;
      
      double div = 0;
      if (FatorPrecoMedio!=0)
         div = (FatorPrecoAtual - FatorPrecoMedio) / FatorPrecoMedio;

      string seta = "signal_" + IntegerToString(i) + "_" + IntegerToString(Counter);
      if (Corr > CORRELACAO_MINIMA)
      {
         int x,y;
         if (div >= PERCENTUAL_TRADE)
         {
            ObjectCreate(seta, OBJ_ARROW_UP, 0, 
               iTime(NULL,TimeFrameTrading,Counter-1), Preco1*FatorPrecoVirtual-Dif);
            ObjectSet(seta,OBJPROP_COLOR,clrGreen);
            ChartTimePriceToXY(0, 0, iTime(NULL,TimeFrameTrading,Counter-1), Preco1*FatorPrecoVirtual-Dif, x, y);
            Label("detSinal_"+IntegerToString(i) + "_" + IntegerToString(Counter), 
               DoubleToString(Corr,2) + " (" + DoubleToString(100*div,1) + "%)", 
               x-50, y-35, Pair[i].Cor, 9, true, true);
         }
         if (div <= -1*PERCENTUAL_TRADE)
         {
            ObjectCreate(seta, OBJ_ARROW_DOWN, 0, 
               iTime(NULL,TimeFrameTrading,Counter-1), Preco1*FatorPrecoVirtual-Dif);
            ObjectSet(seta,OBJPROP_COLOR,clrRed);
            ChartTimePriceToXY(0, 0, iTime(NULL,TimeFrameTrading,Counter-1), Preco1*FatorPrecoVirtual-Dif, x, y);
            Label("detSinal_"+IntegerToString(i) + "_" + IntegerToString(Counter), 
               DoubleToString(Corr,2) + " (" + DoubleToString(100*div,1) + "%)", 
               x-50, y-35, Pair[i].Cor, 9, true, true);
         }
      }
      
      //double iclose0 = iClose(Symbol(),TimeFrameTrading,Counter);
      //double iclose1 = iClose(Pair[i].Ativo,TimeFrameTrading,Counter);
      //double _fator = 0;
      //if (iclose1!=0) _fator = iclose0 / iclose1;

      string ObjName = "close_" + IntegerToString(i) + "_" + IntegerToString(Counter);
      if(ObjectFind(ObjName)<0)
         ObjectCreate(ObjName,
            OBJ_TREND,0,
            iTime(NULL,TimeFrameTrading,Counter-1) ,Preco1     * FatorPrecoVirtual-Dif,
            iTime(NULL,TimeFrameTrading,Counter)   ,Preco1Ant  * FatorPrecoVirtual-Dif);

      ObjectMove(ObjName,0,iTime(NULL,TimeFrameTrading,Counter-1),   Preco1      * FatorPrecoVirtual-Dif);
      ObjectMove(ObjName,1,iTime(NULL,TimeFrameTrading,Counter),     Preco1Ant   * FatorPrecoVirtual-Dif);

      ObjectSet(ObjName,OBJPROP_RAY,false);
      ObjectSet(ObjName,OBJPROP_COLOR,Pair[i].Cor);
      ObjectSet(ObjName,OBJPROP_STYLE, STYLE_DOT);
      ObjectSet(ObjName,OBJPROP_WIDTH, 1);
      
      if (Counter==1)
      {
         int x,y;
         ChartTimePriceToXY(0, 0, TimeCurrent(), Preco1, x, y);
         Label("lblSymbol_"+IntegerToString(i), 
            Pair[i].Ativo + "|" + DoubleToString(Pair[i].Corr,2) + "|" + DoubleToString(FatorPrecoAtual,5), 
            x-150, y1-35, Pair[i].Cor, 9, true, true);
      }
      //else
        // PlotaSeta(Counter,Preco1,FatorPrecoVirtual,x,y,xAnt,i,FatorPrecos,div);
      //{
         //if (Counter>=5)
         //{
            
         //}
      //}
      
      Counter--;
   }
}

int DifTempoEmMinutos(datetime t1, datetime t2)
{
   int dif = (int)MathAbs(t1 - t2)/60;
   return dif;
}

void Label(string _LabelName, string _Text, double _X, double _Y,
   color _color, int _TamanhoFonte, bool Mostrar, bool CoordenadaReal)
   {
   if (_TamanhoFonte<=0) return;
   
   double X0 = _X;
   double Y0 = _Y;

   if (!Mostrar) _Text = " ";

   if (ObjectFind(_LabelName)<0)
      ObjectCreate( _LabelName, OBJ_LABEL, 0, 0, 0 );
   ObjectSetText( _LabelName, _Text, _TamanhoFonte, "Arial", _color );
   if (CoordenadaReal)
   {
      ObjectSet(_LabelName,OBJPROP_XDISTANCE,X0);
      ObjectSet(_LabelName,OBJPROP_YDISTANCE,Y0);
   }
   else
   {
      ObjectSet( _LabelName, OBJPROP_XDISTANCE, 10 + 35 * X0 * _TamanhoFonte);
      ObjectSet( _LabelName, OBJPROP_YDISTANCE, 10 + 1.6 * Y0 * _TamanhoFonte);
   }
   ObjectSet( _LabelName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSet( _LabelName, OBJPROP_ZORDER, 1);
   ChartRedraw();
}


void LoadSymbols()
{
   int i=0;
   int fh = FileOpenHistory("symbols.sel",FILE_BIN|FILE_READ);
   if(fh>0)
   {
      int QtdTotalAtivos = (int)(FileSize(fh)-4) / 0x80;
      string temp;                     
      ArrayResize(Ativos,QtdTotalAtivos);
      
      FileSeek(fh,4,SEEK_SET);
      while(!IsStopped())
      {
         temp = FileReadString(fh,12);
         if(FileIsEnding(fh)) break;
         Ativos[i] = StringSubstr(temp,0,StringFind(temp,"\x00",0));
         i++;
         FileSeek(fh,0x80-12,SEEK_CUR);
      }
      FileClose(fh);
   }
   else
      Print("*** Symbol file not found.");
}