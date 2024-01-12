//+------------------------------------------------------------------+
//|                                                ExpertAdvisor.mqh |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Math/Stat/Math.mqh>
#include <Generic\HashMap.mqh>



class ExpertAdvisor:public CObject{
private:
   long type;
   ulong ticketArr[];
   bool status;
   long magicNumber;
public:
   ExpertAdvisor(long inpType,long inpMagicNumber){
      type = inpType;
      magicNumber = inpMagicNumber;
      this.loadTickets();
   }
   
   bool loadTickets(){
      int realTotal = 0;
      int totalTicket = PositionsTotal();
      ArrayResize(ticketArr,totalTicket);
      for(int i = 0;i<totalTicket;i++){
         ulong positionTicket = PositionGetTicket(i);
         if(positionTicket<=0){Print("Failed to get ticket");return false;}
         if(!PositionSelectByTicket(positionTicket)){Print("Failed to select by ticket");return false;}
         if(magicNumber != PositionGetInteger(POSITION_MAGIC)){continue;}
         if(Symbol() != PositionGetString(POSITION_SYMBOL)){continue;}
         if(type != PositionGetInteger(POSITION_TYPE)){continue;}
         
         ticketArr[realTotal] = positionTicket;
         realTotal++;
      }
      ArrayResize(ticketArr,realTotal);
      return true;
   }
   
   double getProfit(){
      double profit = 0;
      for(int i = 0;i<ArraySize(ticketArr);i++){
         PositionSelectByTicket(ticketArr[i]);
         profit += PositionGetDouble(POSITION_PROFIT);
      }
      return profit;
   }
   
   double getProfitByIndex(int i){
      if(i < 0 || i >= ArraySize(ticketArr)){return -1;}
      PositionSelectByTicket(ticketArr[i]);
      return PositionGetDouble(POSITION_PROFIT);
   }
   
   double getAccLots(){
      double accLots = 0;
      for(int i = 0;i<ArraySize(ticketArr);i++){
         PositionSelectByTicket(ticketArr[i]);
         accLots += PositionGetDouble(POSITION_VOLUME);
      }
      return accLots;
   }
   
   int getTicketArr(ulong& dstArr[]){
      ArrayResize(dstArr,ArraySize(ticketArr));
      return ArrayCopy(dstArr,ticketArr,0,0);
   }
   
   int getTicketCount(){
      return ArraySize(ticketArr);
   }
   
   bool setTicketArr(ulong& srcArr[]){
      ArrayResize(ticketArr,ArraySize(srcArr));
      return ArrayCopy(ticketArr,srcArr,0,0) >= 0;
   }

   long getType(){
      return type;
   }
   
   void clearTicketArr(){
      ArrayFree(ticketArr);
   }
   
   bool getStatus(){
      return ArraySize(ticketArr)>=0;
   }
   
   bool isTicketsEmpty(){
      return ArraySize(ticketArr) == 0;
   }
   
   bool closeAllOrders(){
      bool flag = true;
      for(int i=ArraySize(ticketArr)-1 ; i>=0 ; i--){
         PositionSelectByTicket( ticketArr[i] );
         if(!trade.PositionClose(ticketArr[i])){
            flag = false;
         }
      }
      return flag;
   }
   
   bool closeOrderByIndex(int i){
      if (i<0 || i >= ArraySize(ticketArr)){return false;}
      PositionSelectByTicket( ticketArr[i] );
      if(!trade.PositionClose(ticketArr[i])){
            return false;
      }
      return true;
   }
   
   double getLastLot(){
      if(ArraySize(ticketArr)==0){return 0;}
      PositionSelectByTicket(ticketArr[ArraySize(ticketArr)-1]);
      return PositionGetDouble(POSITION_VOLUME);
   }
   
   double getLastPrice(){
      if(ArraySize(ticketArr)==0){return 0;}
      PositionSelectByTicket(ticketArr[ArraySize(ticketArr)-1]);
      return PositionGetDouble(POSITION_PRICE_OPEN);
   }
   
   datetime getLastOpenTime(){
      if(ArraySize(ticketArr)==0){return 0;}
      PositionSelectByTicket(ticketArr[ArraySize(ticketArr)-1]);
      return PositionGetInteger(POSITION_TIME);
   }

   ulong getLastTicket(){
      if(ArraySize(ticketArr)<=0){return -1;}
      return ticketArr[ArraySize(ticketArr)-1];
   }
};

CTrade trade;