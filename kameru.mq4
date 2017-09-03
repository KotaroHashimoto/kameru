//+------------------------------------------------------------------+
//|                                                       kameru.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

input int Magic_Number = 1;
input double Entry_Lot = 0.1;
extern double TP_pips = 10;
extern double SL_pips = 10;
input double Mask_After_Exit_Min = 5;
input int No_Trade_Start_H = 2;
input int No_Trade_End_H = 10;
input bool London_Summer_Time = True;
input double MACD_yokoyoko_th = 0.01;
input int MACD_yokoyoko_period = 20;

input double Mask_ATR_th = 20;
input int Mask_ATR_period = 20;

const int period = PERIOD_M1;

string thisSymbol;
double minSL;

datetime lastExitTime;


bool allowEntry() {

  if(TimeLocal() - lastExitTime < Mask_After_Exit_Min * 60) {
    return False;
  }
  
  datetime dt = TimeLocal();
  int h = TimeHour(dt);
  int m = TimeMinute(dt);
  if((45 <= m && h == 16 - (int)London_Summer_Time) || (m < 15 && h == 17 - (int)London_Summer_Time)) {
    return False;
  }
  
  if(No_Trade_Start_H <= h && h < No_Trade_End_H) {
    return False;
  }

  double macd_min = 100000;
  double macd_max = -100000;
  for(int i = 0; i < MACD_yokoyoko_period; i++ ) {
    double macd = iMACD(thisSymbol, period, 12, 26, 9, PRICE_WEIGHTED, 0, i);
    
    if(macd < macd_min) {
      macd_min = macd;
    }
    
    if(macd_max < macd) {
      macd_max = macd;
    }
  }

  if(macd_max - macd_min < MACD_yokoyoko_th) {
    return False;
  }
  
  return True;
}


int entryOnPerfectOrder() {

  double atr = iATR(thisSymbol, period, Mask_ATR_period, 0);
  if(Mask_ATR_th < atr) {
    return -1;
  }

  double ma5 = iMA(thisSymbol, period, 5, 0, MODE_SMA, PRICE_WEIGHTED, 0);
  double ma13 = iMA(thisSymbol, period, 13, 0, MODE_SMA, PRICE_WEIGHTED, 0);
  double ma21 = iMA(thisSymbol, period, 21, 0, MODE_SMA, PRICE_WEIGHTED, 0);
  double ma5_1 = iMA(thisSymbol, period, 5, 0, MODE_SMA, PRICE_WEIGHTED, 1);
  double ma13_1 = iMA(thisSymbol, period, 13, 0, MODE_SMA, PRICE_WEIGHTED, 1);
  double ma21_1 = iMA(thisSymbol, period, 21, 0, MODE_SMA, PRICE_WEIGHTED, 1);

  double macd = iMACD(thisSymbol, period, 12, 26, 9, PRICE_WEIGHTED, 0, 0);
  double macd_1 = iMACD(thisSymbol, period, 12, 26, 9, PRICE_WEIGHTED, 0, 1);

  double signal = iMACD(thisSymbol, period, 12, 26, 9, PRICE_WEIGHTED, 1, 0);
  double signal_1 = iMACD(thisSymbol, period, 12, 26, 9, PRICE_WEIGHTED, 1, 1);

  if(macd_1 < signal_1 && signal < macd) {
    return -1;
  }  

  double p0 = iOpen(thisSymbol, period, 0);
  double p1 = iClose(thisSymbol, period, 0);
  if(MathMin(p0, p1) < ma21 && ma21 < MathMax(p0, p1)) {
    return -1;
  }
  

  double high = iHigh(thisSymbol, period, 0);
  double low = iLow(thisSymbol, period, 0);
  if(low < ma5 && ma5 < high) {

    if(macd_1 < macd && ma21_1 < ma21 && ma13_1 < ma13 && ma5_1 < ma5) {
      if(ma21_1 < ma13_1 && ma13_1 < ma5_1 && ma21 < ma13 && ma13 < ma5) {
        return OP_BUY;
      }
    }
    if(macd_1 > macd && ma21_1 > ma21 && ma13_1 > ma13 && ma5_1 > ma5) {
      if(ma21_1 > ma13_1 && ma13_1 > ma5_1 && ma21 > ma13 && ma13 > ma5) {
        return OP_SELL;
      }
    }  
  }
  
  return -1;
}

int countPositions() {

  int n = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        n ++;
      }
    }
  }
  
  return n;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

  thisSymbol = Symbol();
   
  minSL = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
  
  TP_pips *= 10.0 * Point;
  SL_pips *= 10.0 * Point;
  
  lastExitTime = -1;
  
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---

  if(countPositions() == 0) {
  
    if(allowEntry()) {
    
      int op = entryOnPerfectOrder();
    
      if(op == OP_BUY) {
        int ticket = OrderSend(thisSymbol, OP_BUY, Entry_Lot, NormalizeDouble(Ask, Digits), 3, 
                               NormalizeDouble(Ask - SL_pips, Digits), 
                               NormalizeDouble(Ask + TP_pips, Digits), NULL, Magic_Number);
      }
      else if(op == OP_SELL) {
        int ticket = OrderSend(thisSymbol, OP_SELL, Entry_Lot, NormalizeDouble(Bid, Digits), 3, 
                               NormalizeDouble(Bid + SL_pips, Digits), 
                               NormalizeDouble(Bid - TP_pips, Digits), NULL, Magic_Number);
      }
    }
  }
  else {
    lastExitTime = TimeLocal();
  }
}
//+------------------------------------------------------------------+
