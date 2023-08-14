#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
//#include <Arrays/ArrayDouble.mqh>
#include <Generic/HashMap.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Math/Stat/Math.mqh>

static input long    InpMagicnumber = 234234;   // magic number (Integer+)

input double         InpLotSize     = 0.01;     // lot size
input int            InpPeriod      = 3600;     // period (sec)
input int            InpTakeProfit  = 1030;      // take profit in points (point) (0=off)
input int            InpGridStep    = 150;      // step in grid system (point)
input double         InpMaxLotSize  = 0.15;     // max lot size
input double         InpLotMultiply = 1.5;      // multiply lot size
input double         InpPercentTP   = 30;       // percent for greedy! [0-100]
input int            InpMATicket    = 4;        // InpMATicket (Integer+)
input int            InpStopLoss    = 0;        // stop loss in points (pls dont use it!) (point) (0=off)
input double         InpMaxAccLot   = 1;        // ex. InpMaxAccLot = 1 is max of accButLot and accSellLot = 0.5

input int            InpStoKPeriod  = 5;              // Sto K-period (number of bars for calculations)
input int            InpStoDPeriod  = 3;              // Sto D-period (period of first smoothing)
input int            InpStoSlowing  = 3;              // Sto final smoothing
input ENUM_MA_METHOD InpStoMAMethod = MODE_SMA;       // Sto type of smoothing (0 SMA,1 EMA,2 SMMA,3 LWMA )
input ENUM_STO_PRICE InpStoPrice    = STO_LOWHIGH;    // Sto stochastic calculation method (0 LOWHIGH,1 CLOSECLOSE)
input double         InpStoLevel    = 30;             // Sto Level (lower = 50 - level,upper = 50 + level)
input bool           InpStoActive   = false;           // Sto active

input int                  InpRSIMAPeriod = 14;             // RSI averaging period
input ENUM_APPLIED_PRICE   InpRSIAppPrice = PRICE_CLOSE;    // RSI type of price or handle
input double               InpRSILevel    = 20;             // RSI level (lower = 50 - level , upper = 50 + level)
input bool                 InpRSIActive   = false;           // RSI active

input int                  InpCCIMAPeriod = 14;             // CCI averaging period
input ENUM_APPLIED_PRICE   InpCCIAppPrice = PRICE_TYPICAL;  // CCI type of price or handle
input double               InpCCILevel    = 100;            // CCI level (upper = level , lower = -level)
input bool                 InpCCIActive   = true;           // CCI active


input int                  InpMACDFastPeriod    = 12;             // MACD period for Fast average calculation
input int                  InpMACDSlowPeriod    = 26;             // MACD period for Slow average calculation
input int                  InpMACDSignalPeriod  = 9;              // MACD period for their difference averaging
input ENUM_APPLIED_PRICE   InpMACDAppPrice      = PRICE_CLOSE;    // MACD type of price or handle
input double               InpMACDLevel         = 0.004;       // MACD level (lower = 0-level , upper = 0+level)
input ENUM_TIMEFRAMES      InpMACDTimeFrame     = PERIOD_H1;       // MACD timeframe
input bool                 InpMACDActive        = true;           // MACD active


input int            InpHardStoKPeriod  = 5;             // D1 Sto K-period (number of bars for calculations)
input int            InpHardStoDPeriod  = 3;             // D1 Sto D-period (period of first smoothing)
input int            InpHardStoSlowing  = 3;             // D1 Sto final smoothing
input ENUM_MA_METHOD InpHardStoMAMethod = MODE_SMA;      // D1 Sto type of smoothing (0 SMA,1 EMA,2 SMMA,3 LWMA )
input ENUM_STO_PRICE InpHardStoPrice    = STO_LOWHIGH;   // D1 Sto stochastic calculation method (0 LOWHIGH,1 CLOSECLOSE)
input double         InpHardStoLevel    = 30;            // D1 Sto level (lower = 50-level , upper = 50 + level)
input bool           InpHardStoActive   = true;          // D1 Sto active

CTrade trade;
MqlTick currentTick;

double NextBuyPrice;
double accBuyLot;
double dynamicBuyPrice;
double lastestBuyLotSize;
datetime lastestBuyTime;
bool buySignal;
bool buyStatus;

double NextSellPrice;
double accSellLot;
double dynamicSellPrice;
double lastestSellLotSize;
datetime lastestSellTime;
bool sellSignal;
bool sellStatus;

int handleSto;
bool stoBuySignal;
bool stoSellSignal;
double stoMainBuffer[];
double stoSignalBuffer[];

int handleRSI;
double rsiBuffer[];
bool rsiBuySignal;
bool rsiSellSignal;

int handleCCI;
double cciBuffer[];
bool cciBuySignal;
bool cciSellSignal;

int handleMACD;
double macdMainBuffer[];
double macdMainTempBuffer[];
double macdSignalBuffer[];
double macdSignalTempBuffer[];
bool macdBuySignal;
bool macdSellSignal;

int handleHardSto;
double hardStoMainBuffer[];
double hardStoSignalBuffer[];
bool hardStoSellSignal;
bool hardStoBuySignal;

int OnInit(){
   trade.SetExpertMagicNumber(InpMagicnumber);
   
   accBuyLot = 0;
   dynamicBuyPrice = 0;
   lastestBuyLotSize = InpLotSize;
   lastestBuyTime = TimeCurrent();
   buyStatus = false;
   buySignal = false;
   
   accSellLot = 0;
   dynamicSellPrice = 0;
   lastestSellLotSize = InpLotSize;
   lastestSellTime = TimeCurrent();
   sellStatus = false;
   sellSignal = false;

   handleSto = iStochastic( NULL,PERIOD_H1,InpStoKPeriod,InpStoDPeriod,InpStoSlowing,InpStoMAMethod,InpStoPrice ); 
   ArrayResize(stoMainBuffer,1);
   ArrayResize(stoSignalBuffer,1);
   
   handleRSI = iRSI(NULL,PERIOD_H1,InpRSIMAPeriod,InpRSIAppPrice);
   ArrayResize(rsiBuffer,1);
   
   handleCCI = iCCI(NULL,PERIOD_H1,InpCCIMAPeriod,InpCCIAppPrice);
   ArrayResize(cciBuffer,1);
   
   handleMACD = iMACD(NULL,InpMACDTimeFrame,InpMACDFastPeriod,InpMACDSlowPeriod,InpMACDSignalPeriod,InpMACDAppPrice);
   ArrayResize(macdMainBuffer,1);
   ArrayResize(macdMainTempBuffer,1);
   ArrayResize(macdSignalBuffer,1);
   ArrayResize(macdSignalTempBuffer,1);
   
   handleHardSto = iStochastic(NULL,PERIOD_D1,InpHardStoKPeriod,InpHardStoDPeriod,InpHardStoSlowing,InpHardStoMAMethod,InpHardStoPrice);
   ArrayResize(hardStoMainBuffer,1);
   ArrayResize(hardStoSignalBuffer,1);
   
   if(PositionsTotal()>0){Recovery();}
   
   return(INIT_SUCCEEDED);
}

void Recovery(){
   ulong ticketBuyArr[];
   ulong ticketSellArr[];
   GetAllTicket(ticketBuyArr,ticketSellArr);
   
   accBuyLot = 0;
   dynamicBuyPrice = 0;
   lastestBuyLotSize = InpLotSize;
   NextBuyPrice = 0;
   buyStatus = false;
   buySignal = false;
   
   accSellLot = 0;
   dynamicSellPrice = 0;
   lastestSellLotSize = InpLotSize;
   NextSellPrice = 0;
   sellStatus = false;
   sellSignal = false;
   
   for(int i=ArraySize(ticketBuyArr)-1;i>=0;i--){
      PositionSelectByTicket( ticketBuyArr[i] );
      double priceOpen = 0;
      PositionGetDouble(POSITION_PRICE_OPEN,priceOpen);
      double lotSize = 0;
      PositionGetDouble(POSITION_VOLUME,lotSize);
      
      buyStatus = true;
      dynamicBuyPrice = (dynamicBuyPrice*accBuyLot + priceOpen*lotSize)/(accBuyLot + lotSize);
      accBuyLot += lotSize;
      lastestBuyLotSize = MathMax( lastestBuyLotSize,lotSize );
      NextBuyPrice = (NextBuyPrice==0) ? priceOpen : MathMin(NextBuyPrice,priceOpen);
   }
   
   for(int i=ArraySize(ticketSellArr)-1;i>=0;i--){
      PositionSelectByTicket( ticketSellArr[i] );
      double priceOpen = 0;
      PositionGetDouble(POSITION_PRICE_OPEN,priceOpen);
      double lotSize = 0;
      PositionGetDouble(POSITION_VOLUME,lotSize);
      
      sellStatus = true;
      dynamicSellPrice = (dynamicSellPrice*accSellLot + priceOpen*lotSize)/(accSellLot + lotSize);
      accSellLot += lotSize;
      lastestSellLotSize = MathMax( lastestSellLotSize,lotSize );
      NextSellPrice = (NextSellPrice==0) ? priceOpen : MathMax(NextSellPrice,priceOpen);
   }
   
   if(buyStatus){
      LotSizeUpdate("buy");
      NextBuyPrice -= InpGridStep*_Point;
   }
   if(sellStatus){
      LotSizeUpdate("sell");
      NextSellPrice += InpGridStep*_Point;
   }
   
}

void OnDeinit(const int reason){
}

void OnTick(){
   if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get tick");return;}
   
   if(IsNewBar()){Recovery();UpdateIndicatorBuffer();SignalByIndicator();}
   
   CloseOrder();
   
   if(!buyStatus){NextBuyPrice=currentTick.ask;}
   if(!sellStatus){NextSellPrice=currentTick.bid;}
   
   if(currentTick.ask<=NextBuyPrice && lastestBuyTime + InpPeriod <= currentTick.time && buySignal && accBuyLot + lastestBuyLotSize < InpMaxAccLot/2 ){

      if(trade.Buy(lastestBuyLotSize,NULL,currentTick.ask,0,0,NULL)){
         dynamicBuyPrice = ( dynamicBuyPrice*accBuyLot + currentTick.ask*lastestBuyLotSize )/(accBuyLot + lastestBuyLotSize);
         accBuyLot += lastestBuyLotSize;
         NextBuyPrice = currentTick.ask - InpGridStep * _Point;
         lastestBuyTime = currentTick.time;
         buyStatus = true;
         LotSizeUpdate("buy");
      }

   }
   
   if(currentTick.bid>=NextSellPrice && lastestSellTime + InpPeriod <= currentTick.time && sellSignal && accSellLot + lastestSellLotSize < InpMaxAccLot/2 ){

      if(trade.Sell(lastestSellLotSize,NULL,currentTick.bid,0,0,NULL)){
         dynamicSellPrice = ( dynamicSellPrice*accSellLot + currentTick.bid*lastestSellLotSize )/(accSellLot + lastestSellLotSize);
         accSellLot += lastestSellLotSize;
         NextSellPrice = currentTick.bid + InpGridStep*_Point;
         lastestSellTime = currentTick.time;
         sellStatus = true;
         LotSizeUpdate("sell");
      }
   }

   Comment("Ask: ",currentTick.ask," NextBuyPrice: ",NextBuyPrice," DynamicBuyPrice: ",dynamicBuyPrice," accBuyLot: ",accBuyLot,
         "\nBid: ",currentTick.bid," NextSellPrice: ",NextSellPrice," DynamicSellPrice: ",dynamicSellPrice," accSellLot: ",accSellLot,
         "\nSpread: ",currentTick.ask - currentTick.bid,
         "\nlastestBuyLotSize: ",lastestBuyLotSize," lastestBuyTime: ",lastestBuyTime," buyStatus: ",buyStatus," buySignal: ",buySignal,
         "\nlastestSellLotSize: ",lastestSellLotSize," lastestSellTime: ",lastestSellTime," sellStatus",sellStatus," sellSignal: ",sellSignal
         );
         //"\n",stoMainTempBuffer[0]," ",//stoMainTempBuffer[1]," ",stoMainTempBuffer[2]," ",stoMainTempBuffer[3],
         //"\n",MathRound(macdMainTempBuffer[0],6)," ",MathRound(macdMainTempBuffer[1],6)," ",MathRound(macdMainTempBuffer[2],6)," ",MathRound(macdMainTempBuffer[3],6)," ",MathRound(macdMainTempBuffer[4],6)," ",MathRound(macdMainTempBuffer[5],6),
         //"\n",rsiBuffer[0],
         //"\n",cciBuffer[0],
         //"\n",stoMainBuffer[0],//,stoMainBuffer[1]," ",stoMainBuffer[2]," ",stoMainBuffer[3]," ",stoMainBuffer[4]," ",stoMainBuffer[5]," ",stoMainBuffer[6]
         //"\n",stoSignalBuffer[0],
         //"\n",macdMainBuffer[0]," ",macdSignalBuffer[0],
         //"\n",macdMainTempBuffer[0]," ",macdSignalTempBuffer[0]
         //);
         //"\nhardStoBuySignal: ",hardStoBuySignal," hardStoSellSignal: ",hardStoSellSignal,
         //"\nstoBuySignal: ",stoBuySignal," stoSellSignal: ",stoSellSignal,
         //"\nrsiBuySignal: ",rsiBuySignal," rsiSellSignal: ",rsiSellSignal,
         //"\ncciBuySignal: ",cciBuySignal," cciSellSignal: ",cciSellSignal,
}

void LotSizeUpdate(string cmd){
   if(cmd=="buy"){
      lastestBuyLotSize = (lastestBuyLotSize*InpLotMultiply > InpMaxLotSize) ? InpMaxLotSize : (double)((ceil(lastestBuyLotSize*InpLotMultiply*100))/100);
   }else{
      lastestSellLotSize = (lastestSellLotSize*InpLotMultiply > InpMaxLotSize) ? InpMaxLotSize : (double)((ceil(lastestSellLotSize*InpLotMultiply*100))/100);
   }
}

void CloseOrder(){
   int totalTicket = PositionsTotal();
   if(totalTicket==0){return;}
   
   ulong ticketBuyArr[];
   ulong ticketSellArr[];
   
   if(!GetAllTicket(ticketBuyArr,ticketSellArr)){
      Print("CloseOrder : Failed to get ticket array ",PositionsTotal());
      return;
   }
   
   if(buyStatus){
      if(ArraySize(ticketBuyArr) > InpMATicket){
         if(CloseOrderReduceDrawdown(ticketBuyArr)){
            CloseOrderMAOpen(ticketBuyArr);
         }
      }else{
         CloseOrderMAOpen(ticketBuyArr);
      }
   }
   
   if(sellStatus){
      
      if(ArraySize(ticketSellArr) > InpMATicket){
         if(CloseOrderReduceDrawdown(ticketSellArr)){
            CloseOrderMAOpen(ticketSellArr);
         }
      }else{
         CloseOrderMAOpen(ticketSellArr);
      }
   }
}

long ticketArrType(ulong& ticketArr[]){
   PositionSelectByTicket( ticketArr[0] );
   return PositionGetInteger(POSITION_TYPE);
}

bool CloseOrderMAOpen(ulong& ticketArr[]){
   long type = ticketArrType(ticketArr);

   double netProfit = 0; 

   int totalTicket = ArraySize(ticketArr);
   
   if(type==POSITION_TYPE_BUY){
      netProfit = (currentTick.bid - dynamicBuyPrice);
      
      if( InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accBuyLot ){
         Print("Buy - Stop Loss active");
      }
      
      if(netProfit>=(InpTakeProfit*_Point)*InpLotSize/accBuyLot  || (InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accBuyLot )){
         bool tempF = true;
         for(int i = totalTicket-1;i>=0;i--){
            PositionSelectByTicket( ticketArr[i] );
            double tempO,tempL;
            PositionGetDouble(POSITION_PRICE_OPEN,tempO);
            PositionGetDouble(POSITION_VOLUME,tempL);
            if(trade.PositionClose(ticketArr[i])){
               if(accBuyLot-tempL>0){
                  dynamicBuyPrice = (dynamicBuyPrice*accBuyLot - tempO*tempL) / (accBuyLot - tempL);
                  accBuyLot -= tempL;
               }else{
                  dynamicBuyPrice = 0;
                  accBuyLot = 0;
               }
            }else{
               tempF = false;
            }
         }
         if(tempF){
            Print( "MA BUY : netProfit : ",netProfit );
            accBuyLot = 0;
            dynamicBuyPrice = 0;
            lastestBuyLotSize = InpLotSize;
            buyStatus = false;
            return true;
         }
      }else{
         return false;
      }

   }else if(type==POSITION_TYPE_SELL){
      netProfit = (dynamicSellPrice - currentTick.ask);
      
      if( InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accSellLot ){
         Print("Sell - Stop Loss active");
      }
      
      if(netProfit>=(InpTakeProfit*_Point)*InpLotSize/accSellLot || (InpStopLoss > 0 && -netProfit >= (InpStopLoss*_Point)*InpLotSize/accSellLot )){
         bool tempF = true;
         for(int i = totalTicket-1;i>=0;i--){
            PositionSelectByTicket( ticketArr[i] );
            double tempO,tempL;
            PositionGetDouble(POSITION_PRICE_OPEN,tempO);
            PositionGetDouble(POSITION_VOLUME,tempL);
            if(trade.PositionClose(ticketArr[i])){
               if( accSellLot-tempL!=0 ){
                  dynamicSellPrice = (dynamicSellPrice*accSellLot - tempO*tempL) / (accSellLot - tempL);
                  accSellLot -= tempL;
               }else{
                  dynamicSellPrice = 0;
                  accSellLot = 0;
               }
            }
            else{
               tempF = false;
            }
         }
         if(tempF){
            Print( "MA SELL : netProfit : ",netProfit );
            accSellLot = 0;
            dynamicSellPrice = 0;
            lastestSellLotSize = InpLotSize;
            sellStatus = false;
            return true;
         }
      }else{
         return false;
      }
   }
   return false;
}

bool CloseOrderReduceDrawdown(ulong& ticketArr[]){
   long type = ticketArrType(ticketArr);

   while(true){
      if( ArraySize(ticketArr) <= InpMATicket ){
         return true;
      }
      PositionSelectByTicket(ticketArr[ ArraySize(ticketArr)-1 ]);
      double lastLotSize = PositionGetDouble(POSITION_VOLUME);
      double lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      PositionSelectByTicket(ticketArr[ 0 ]);
      double firstLotSize = PositionGetDouble(POSITION_VOLUME);
      double firstOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      double profit = 0;
      double accLot = 0;
      if(type==POSITION_TYPE_BUY){
         profit = ((currentTick.bid-lastOpenPrice)*lastLotSize + (currentTick.bid-firstOpenPrice)*firstLotSize);
         accLot = accBuyLot;
      }else{
         profit = ((lastOpenPrice-currentTick.ask)*lastLotSize + (firstOpenPrice-currentTick.ask)*firstLotSize);
         accLot = accSellLot;
      }
      
      double profitDD = 0;
      if(InpPercentTP > 0){profitDD = InpTakeProfit*_Point*(firstLotSize + lastLotSize)*(InpPercentTP/100);}
      else{profitDD = InpTakeProfit*_Point*InpLotSize;}
      
      if(profit >= profitDD ){
         int tempFlagLast = 0;
         if(trade.PositionClose(ticketArr[ ArraySize(ticketArr)-1 ])){
            tempFlagLast = 1;
            ArrayRemove(ticketArr, ArraySize(ticketArr)-1 ,1);
         }
         
         int tempFlagFirst = 0;
         if(trade.PositionClose(ticketArr[ 0 ])){
            tempFlagFirst = 1;
            ArrayRemove(ticketArr, 0 ,1);
         }
         
         if(!tempFlagFirst && !tempFlagLast){
            return false;
         }
         
         if(type==POSITION_TYPE_BUY){
            Print("ReduceDD : Buy : profit : ",profit," profitDD : ",profitDD," ",tempFlagLast," ",tempFlagFirst);
            dynamicBuyPrice = (dynamicBuyPrice*accBuyLot - tempFlagLast*lastOpenPrice*lastLotSize - tempFlagFirst*firstOpenPrice*firstLotSize) / (accBuyLot - tempFlagLast*lastLotSize - tempFlagFirst*firstLotSize);
            accBuyLot = accBuyLot - tempFlagFirst*firstLotSize - tempFlagLast*lastLotSize;
         }else{
            Print("ReduceDD : Sell : profit : ",profit," profitDD : ",profitDD," ",tempFlagLast," ",tempFlagFirst);
            dynamicSellPrice = (dynamicSellPrice*accSellLot - tempFlagLast*lastOpenPrice*lastLotSize - tempFlagFirst*firstOpenPrice*firstLotSize) / (accSellLot - tempFlagLast*lastLotSize - tempFlagFirst*firstLotSize);
            accSellLot = accSellLot - tempFlagFirst*firstLotSize - tempFlagLast*lastLotSize;
         }
      }else{
         return false;
      }
   }
}

bool GetAllTicket(ulong& ticketBuyArr[],ulong& ticketSellArr[]){
   int totalTicket = PositionsTotal();
   ArrayResize(ticketBuyArr,totalTicket);
   ArrayResize(ticketSellArr,totalTicket);
   int buyTicket = 0;
   int sellTicket = 0;
   int realTotal = 0;
   for(int i = 0;i<totalTicket;i++){
      ulong positionTicket = PositionGetTicket(i);
      if(positionTicket<=0){Print("Failed to get ticket");return false;}
      if(!PositionSelectByTicket(positionTicket)){Print("Failed to select position");return false;}
      
      if(Symbol() != PositionGetString(POSITION_SYMBOL)){continue;}
      
      long magic,type;
      if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get magic");return false;}
      if(magic!=InpMagicnumber){//Print("magic invalid");
         continue;
      }
      realTotal++;
      type = PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY){
         ticketBuyArr[buyTicket] = positionTicket;
         buyTicket++;
      }else{
         ticketSellArr[sellTicket] = positionTicket;
         sellTicket++;
      }
   }
   if(buyTicket+sellTicket != realTotal){Print("number of ticket invalid ! ",realTotal," ",buyTicket+sellTicket);return false;}
   ArrayResize(ticketBuyArr,buyTicket);
   ArrayResize(ticketSellArr,sellTicket);
   return true;
}

void UpdateIndicatorBuffer(){
   CopyBuffer( handleSto,MAIN_LINE,0,1,stoMainBuffer );
   CopyBuffer( handleSto,SIGNAL_LINE,0,1,stoSignalBuffer );

   CopyBuffer( handleRSI,MAIN_LINE,0,1,rsiBuffer );
   CopyBuffer( handleCCI,MAIN_LINE,0,1,cciBuffer );
   
   ArrayCopy( macdMainTempBuffer,macdMainBuffer );
   ArrayCopy( macdSignalTempBuffer,macdSignalBuffer );
   CopyBuffer( handleMACD,MAIN_LINE,0,1,macdMainBuffer );
   CopyBuffer( handleMACD,SIGNAL_LINE,0,1,macdSignalBuffer );
   
   CopyBuffer( handleHardSto,MAIN_LINE,0,1,hardStoMainBuffer );
   CopyBuffer( handleHardSto,SIGNAL_LINE,0,1,hardStoSignalBuffer );
}

void SignalByIndicator(){
   HardStoSignal();
   StoSignal();
   RSISignal();
   CCISignal();
   MACDSignal();
   buySignal = ( hardStoBuySignal || !InpHardStoActive ) && 
               ( stoBuySignal || !InpStoActive ) && 
               ( rsiBuySignal || !InpRSIActive ) && 
               ( cciBuySignal || !InpCCIActive ) &&
               ( macdBuySignal || !InpMACDActive );
   sellSignal = ( hardStoSellSignal || !InpHardStoActive ) && 
                ( stoSellSignal || !InpStoActive ) && 
                ( rsiSellSignal || !InpRSIActive ) && 
                ( cciSellSignal || !InpCCIActive ) && 
                ( macdSellSignal || !InpMACDActive );
}

void StoSignal(){
   stoBuySignal = true;
   stoSellSignal = true;
   
   if(stoMainBuffer[0] >= 50 + InpStoLevel || stoSignalBuffer[0] >= 50 + InpStoLevel ){
      stoBuySignal = false;
   }
   else if( stoMainBuffer[0] <= 50 - InpStoLevel || stoSignalBuffer[0] <= 50 - InpStoLevel ){
      stoSellSignal = false;
   }
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

void RSISignal(){
   rsiBuySignal = true;
   rsiSellSignal = true;
   if(rsiBuffer[0] >= InpRSILevel + 50){
      rsiBuySignal = false;
   }else if(rsiBuffer[0] <= 50 - InpRSILevel){
      rsiSellSignal = false;
   }
}

void HardStoSignal(){
   hardStoBuySignal = true;
   hardStoSellSignal = true;
   if( hardStoMainBuffer[0] >= 50+InpHardStoLevel || hardStoSignalBuffer[0] >= 50+InpHardStoLevel ){
      hardStoBuySignal = false;
   }else if( hardStoMainBuffer[0] <= 50-InpHardStoLevel || hardStoSignalBuffer[0] <= 50-InpHardStoLevel ){
      hardStoSellSignal = false;
   }
}

void CCISignal(){
   cciBuySignal = true;
   cciSellSignal = true;
   if(cciBuffer[0] >= InpCCILevel){
      cciBuySignal = false;
   }else if(cciBuffer[0] <= -InpCCILevel){
      cciSellSignal = false;
   }
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol,PERIOD_H1,0);
   if(previousTime!=currentTime){
      previousTime = currentTime;
      return true;
   }
   return false;
}


