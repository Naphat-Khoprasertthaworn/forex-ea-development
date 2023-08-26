#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

static input long    InpMagicnumber    = 234234;   // magic number (Integer+)

input double         InpLotInit        = 0.01;     // Initial lot size
input double         InpLotMultiply    = 2;        // Multiply lot size
input double         InpLotMax         = 0.64;     // Max lot size
input double         InpLotMaxAcc      = 1;        // Max accumulate lot size

input int            InpGridInit       = 150;      // Initial step in grid system (point)
input double         InpGridMultiply   = 2;        // Multiply grid step
input int            InpGridMax        = 1200;     // Max grid step

input int            InpTP          = 300;      // Take profit in points (point) (0=off)
input double         InpTPPercent   = 30;       // Ratio of take profit when closing order matching 

input int            InpDDMax       = 30;       // Maximum drawdown (relative)
input int            InpMATicket    = 4;        // Maximum ticket for closing by moving average
input int            InpCooldown    = 3600;     // Cooldown (sec)
input int            InpStopLoss    = 0;        // Stop loss (point) (0=off)

input int                  InpMACDFastPeriod    = 12;             // MACD period for Fast average calculation
input int                  InpMACDSlowPeriod    = 26;             // MACD period for Slow average calculation
input int                  InpMACDSignalPeriod  = 9;              // MACD period for their difference averaging
input ENUM_APPLIED_PRICE   InpMACDAppPrice      = PRICE_CLOSE;    // MACD type of price or handle
input double               InpMACDLevel         = 0.004;          // MACD level (lower = 0-level , upper = 0+level)
input ENUM_TIMEFRAMES      InpMACDTimeFrame     = PERIOD_H1;      // MACD timeframe
input bool                 InpMACDActive        = true;           // MACD active

CTrade trade;
MqlTick currentTick;

double lastOpenPrice;
double dynamicOpenPrice;
double lastLot;
double accLot;
datetime lastTime;

bool buyStatus;
bool sellStatus;

int handleMACD;
double macdMainBuffer[];
double macdMainTempBuffer[];
double macdSignalBuffer[];
double macdSignalTempBuffer[];
bool macdBuySignal;
bool macdSellSignal;




int OnInit(){
   trade.SetExpertMagicNumber(InpMagicnumber);
   
   lastLot = 0;
   accLot = 0;
   lastTime = TimeCurrent();
   dynamicOpenPrice = 0;
   
   macdBuySignal = false;
   macdSellSignal = false;
   
   handleMACD = iMACD(NULL,InpMACDTimeFrame,InpMACDFastPeriod,InpMACDSlowPeriod,InpMACDSignalPeriod,InpMACDAppPrice);
   ArrayResize(macdMainBuffer,1);
   ArrayResize(macdMainTempBuffer,1);
   ArrayResize(macdSignalBuffer,1);
   ArrayResize(macdSignalTempBuffer,1);
   
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

   
}

void OnTick(){

   
}

void LotSizeUpdate(){
   lastLot = (lastLot*InpLotMultiply > InpLotMax) ? InpLotMax : (double)((ceil(lastLot*InpLotMultiply*100))/100)
}

void MACDSignal(){
   macdBuySignal = false;
   macdSellSignal = false;
   if( macdMainBuffer[0] < InpMACDLevel && macdSignalBuffer[0] < InpMACDLevel && macdMainTempBuffer[0] <= macdSignalTempBuffer[0] && macdMainBuffer[0] > macdSignalBuffer[0] ){
      macdBuySignal = true;
   }
   else if( macdMainBuffer[0] > -InpMACDLevel && macdSignalBuffer[0] > -InpMACDLevel && macdMainTempBuffer[0] >= macdSignalTempBuffer[0] && macdMainBuffer[0] < macdSignalBuffer[0] ){
      macdSellSignal = true;
   }
}

