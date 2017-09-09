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

input int Magic_Number = 1; //マジックナンバー
input double Entry_Lot = 0.1; //エントリーロット数
extern double TP_pips = 10; //利確幅[pips]
extern double SL_pips = 10; //損切幅[pips]

input double Mask_After_Exit_Min = 5; //決済後のエントリー禁止期間[分]
input int No_Trade_Start_H = 2; //エントリー禁止時間開始[時]
input int No_Trade_End_H = 10; //エントリー禁止時間終了[時]

input bool London_Summer_Time = True; //ロンドンサマータイム

input double MACD_yokoyoko_th = 0.01; //MACD横ばい判定閾値
input int MACD_yokoyoko_period = 20; //MACD横ばい判定期間

extern double Mask_ATR_th = 20; //ボラ(ATR)判定閾値(pips)
input int Mask_ATR_period = 20; //ボラ(ATR)判定期間

extern double Narrow_Factor = 30; // ma13とma5の差がma21とma13のX%より小さいときをエントリー対象とする
extern double Slope_Det_Factor = 10; // ATRのX%だけ傾きがあるときをエントリー対象とする

const int period = PERIOD_M5;

string thisSymbol;
double minSL;

datetime lastExitTime;


//エントリーしない共通条件の判定
bool allowEntry() {

  //決済が終わったあと5分間はエントリーしない
  if(TimeLocal() - lastExitTime < Mask_After_Exit_Min * 60) {
    return False;
  }
  
  datetime dt = TimeLocal();
  int h = TimeHour(dt);
  int m = TimeMinute(dt);

  //ロンドン市場が開く前後15分間はエントリーしない
  if((45 <= m && h == 16 - (int)London_Summer_Time) || (m < 15 && h == 17 - (int)London_Summer_Time)) {
    return False;
  }

  //深夜2時から翌日10時まではエントリーしない  
  if(No_Trade_Start_H <= h && h < No_Trade_End_H) {
    return False;
  }

  double macd_min = 100000;
  double macd_max = -100000;

  //MACDが横ばいのときはエントリーしない
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

  //上記のいずれの条件にも引っかからなかったらエントリー許可
  return True;
}


// 1.パーフェクトオーダーによるエントリー判定
int entryOnPerfectOrder() {

  //ボラ(ATR)か20pipsより大きいときはエントリーしない
  double atr = iATR(thisSymbol, period, Mask_ATR_period, 0);
  if(Mask_ATR_th < atr) {
    return -1;
  }

  double ma5 = iMA(thisSymbol, period, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
  double ma13 = iMA(thisSymbol, period, 13, 0, MODE_SMA, PRICE_CLOSE, 0);
  double ma21 = iMA(thisSymbol, period, 21, 0, MODE_SMA, PRICE_CLOSE, 0);
  double ma5_1 = iMA(thisSymbol, period, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
  double ma13_1 = iMA(thisSymbol, period, 13, 0, MODE_SMA, PRICE_CLOSE, 1);
  double ma21_1 = iMA(thisSymbol, period, 21, 0, MODE_SMA, PRICE_CLOSE, 1);

  double macd = iMACD(thisSymbol, period, 12, 26, 9, PRICE_CLOSE, 0, 0);
  double macd_1 = iMACD(thisSymbol, period, 12, 26, 9, PRICE_CLOSE, 0, 1);

  double signal = iMACD(thisSymbol, period, 12, 26, 9, PRICE_CLOSE, 1, 0);
  double signal_1 = iMACD(thisSymbol, period, 12, 26, 9, PRICE_CLOSE, 1, 1);

  //MACDとシグナルがクロスしているときはエントリーしない
  if(macd_1 < signal_1 && signal < macd) {
    return -1;
  }  

  //ローソク足本体が21日線に触れているときはエントリーしない
  double p0 = iOpen(thisSymbol, period, 0);
  double p1 = iClose(thisSymbol, period, 0);
  if(MathMin(p0, p1) < ma21 && ma21 < MathMax(p0, p1)) {
    return -1;
  }
  

  double high = iHigh(thisSymbol, period, 0);
  double low = iLow(thisSymbol, period, 0);

  double th = atr * Slope_Det_Factor;

  //ローソク足が移動平均5日線に触れたときにエントリー
  if(low < ma5 && ma5 < high) {

    //３つの移動平均線とMACDがすべて右肩上がり
    if(macd_1 < macd && ma21_1 + th < ma21 && ma13_1 + th < ma13 && ma5_1 + th < ma5) {
      
      //下から21日線、13日線、5日線の順になっているときは買いエントリー
      if(ma21_1 < ma13_1 && ma13_1 < ma5_1 && ma21 < ma13 && ma13 < ma5) {

       //21日線と13日線の差よりも、13日線と5日線との差が小さいときにエントリー
        if(Narrow_Factor * (ma13 - ma21) > ma5 - ma13) {
 
          double q0 = iOpen(thisSymbol, period, 1);
          double q1 = iClose(thisSymbol, period, 1);
      
          if(q0 < q1 && q1 < p0 && p0 > p1 && (q0 + q1) / 2.0 > p1) {
            return -1;
          }
        
          return OP_BUY;
        }
      }
    }

    //３つの移動平均線とMACDがすべて右肩下がり
    if(macd_1 > macd && ma21_1 > th + ma21 && ma13_1 > th + ma13 && ma5_1 > th + ma5) {

      //上から21日線、13日線、5日線の順になっているときは売りエントリー
      if(ma21_1 > ma13_1 && ma13_1 > ma5_1 && ma21 > ma13 && ma13 > ma5) {
      
        //21日線と13日線の差よりも、13日線と5日線との差が小さいときにエントリー
        if(Narrow_Factor * (ma21 - ma13) > ma13 - ma5) {

          double q0 = iOpen(thisSymbol, period, 1);
          double q1 = iClose(thisSymbol, period, 1);
      
          if(q0 > q1 && q1 > p0 && p0 < p1 && (q0 + q1) / 2.0 < p1) {
            return -1;
          }

          return OP_SELL;
        }
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
  Mask_ATR_th *= 10.0 * Point;
  
  Narrow_Factor *= 0.01;
  Slope_Det_Factor *= 0.01;
  
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

  //ポジションを保有していなかったらエントリー条件判定
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
