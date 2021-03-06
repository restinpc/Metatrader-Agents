//+------------------------------------------------------------------+
//|                                                Brain Project.mq5 |
//|                                    Copyright 2018, Brain Project |
//+------------------------------------------------------------------+
#property version       "1.82"
#property strict
string url = "https://{api_url}";
//+------------------------------------------------------------------+
input string   Email = "";
input string   Password = "";
enum confirm{ Automatic, SemiAutomatic };
input confirm  Mode = Automatic;
//+------------------------------------------------------------------+
int error_connect = 0;
int error_order = 0;
int timer_interval = 60;
int request_delay = 5000;
bool is_exec = false;
double version = 1.82;
int last_signal = -1;
string id = "Brain Project "+version;
#define OP_BUY 0                                            //Покупка 
#define OP_SELL 1                                           //Продажа 
#include <Trade\Trade.mqh>
CTrade trader;
//+-----------------------------------------------------------------+
string lang[] = {
"Allow WebRequest for an URL \"https://brain-project.online/api.php\" in Tools->Options->Expert",
"Request Error #",
"Error connecting to server",
"The trading advisor works correctly only for the EUR/USD pair",
"Server Error",
"Error. Invalid email or password",
"Error. Free Trial plan is expired.\r\nTo continue, update the plan to Premium on the site of the system https://brain-project.online",
"Error. Your Premium plan is expired.\r\nTo continue, process a payment on the site of the system https://brain-project.online",
"Error. Your account has not been activated.\r\nTo continue, complete a data validation on the site of the system https://brain-project.online/account",
"Error. There is a technical works are in process on the system.\r\nFor more information, visit the site of the system https://brain-project.online",
"Command OrderClose returns an error #",
"Command OrderModify returns an error #",
"Command OrderSend returns an error #",
"Trading advisor \"Brain Project\" successfully launched",
"An error occurred launch of \"Brain Project\" trading advisor",
"Invalid lot size. Check the settings of the trading advisor",
"By running the trading advisor, you confirm that you are aware of all the risks associated with trading in Forex and refuse any claims to the developers of the analytical system \"Brain Project\".",
"Initialization of Brain Project",
"The trading advisor \"Brain Project\" has been canceled by the user.",
"Command OrderSelect returns an error #",
"Sorry, the trading advisor \"Brain Project\" does not work in the strategy tester.",
"You are using an older version of the Expert Advisor.\r\nTo continue, you need to download the latest version from the site of the system https://brain-project.online",
"Command WebRequest is successfully completed",
"Command EventSetTimer returns an error #",
"Command WebRequest returns an error #",
"Confirmation of the action of the trade adviser \"Brain Project\"",
"Brain Project is expect an uptrend in the EUR/USD",
"Brain Project is expect a downtrend in the EUR/USD", 
"Confirm the opening of a new buy position of",
"Confirm the opening of a new sell position of",
"lost",
"Confirm the closing of a buy position",
"Confirm the closing of a sell position",
"For using Trading Adviser, you need an account on the site https://brain-project.online"
};
//+------------------------------------------------------------------+
int brain(string server_data){
   string data[];
   if(StringSubstr(Symbol(),0,6) != "EURUSD"){
      MessageBox(lang[3]); 
      return 0;
   }
   if(server_data == NULL){
      char post[], result[];
      string headers;
      int res = WebRequest("GET", url+"?email="+Email+"&pass="+Password+"&sync=1", NULL, NULL, request_delay, post, 0, result, headers);
      if(res == -1){
         Print(lang[24]+GetLastError());
         if(GetLastError() == 4060){
            MessageBox(lang[0]); 
            return 0;  
         }else{
            if(GetLastError() != 0){
               Alert(lang[1]+GetLastError()); 
            }else{
               if(error_connect > 3){
                  Alert(lang[2]);
               }
               error_connect++;
            }
            Sleep(request_delay);
            return brain(NULL);
         }       
      }else{
         Print(lang[22]);
         error_connect = 0;
         server_data = CharArrayToString(result);
         if(server_data == "error"){
            MessageBox(lang[4]); 
            return 0;     
         }else if(server_data == "error_1"){
            MessageBox(lang[5]); 
            return 0;     
         }else if(server_data == "error_2"){
            MessageBox(lang[6]); 
            return 0;     
         }else if(server_data == "error_3"){
            MessageBox(lang[7]);
            return 0; 
         }else if(server_data == "error_4"){    
            MessageBox(lang[8]);
            return 0; 
         }else if(server_data == "error_5"){    
            MessageBox(lang[9]);
            return 0; 
         }else if(server_data == "weekend"){
            return 1;
         }
      }
   }
   StringSplit(server_data,';',data);
   if(ArraySize(data) != 4){ 
      Sleep(request_delay);
      return brain(NULL);
   }
   double api_version = StringToDouble(data[0]);
   if(version != api_version){
      MessageBox(lang[21]);
      return 0;
   }
   string signal = data[1];
   if(signal != last_signal){
      if(signal == "0"){
         Alert(lang[26]);
      }else if(signal == "1"){
         Alert(lang[27]);
      }
      last_signal = signal;
   }
   double buy_signal = StringToInteger(data[2]);
   double sell_signal = StringToInteger(data[3]);
   bool is_buy = false;
   bool is_sell = false;
   double lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(AccountInfoString(ACCOUNT_CURRENCY) == "USD"){
      lot = (AccountInfoDouble(ACCOUNT_BALANCE)/100000);
   }else if(AccountInfoString(ACCOUNT_CURRENCY) == "EUR"){
      lot = ((AccountInfoDouble(ACCOUNT_BALANCE)/100000)*SymbolInfoDouble(Symbol(),SYMBOL_ASK));
   }else{
      lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN); 
   }
   if(lot < SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN)){
      lot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   }else if(lot > SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX)){
      lot = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   }else{
      double mod = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
      lot = mod * MathRound(lot/mod);
   }
   buy_signal *= lot;
   sell_signal *= lot;
   int total = PositionsTotal();
   for(int pos=0; pos<total; pos++){
      bool order_select = false;
      do{
         order_select = PositionSelectByTicket(PositionGetTicket(pos));
         if(order_select != true){
            if(error_order > 3){
               Alert(lang[19]+GetLastError());
               error_order = 0;
            }
            error_order++;
            Sleep(request_delay);
         }else{
            error_order = 0;
         }
      }while(order_select != true);
      if(StringSubstr(PositionGetString(POSITION_COMMENT), 0, 18) == id && PositionGetString(POSITION_SYMBOL) == Symbol()){
         if(PositionGetInteger(POSITION_TYPE) == OP_BUY){
            is_buy = true;
         }else{
            is_sell = true;
         }
         if((PositionGetInteger(POSITION_TYPE) == OP_BUY && buy_signal != PositionGetDouble(POSITION_VOLUME)) || 
            (PositionGetInteger(POSITION_TYPE) == OP_SELL && sell_signal != PositionGetDouble(POSITION_VOLUME))){
            bool action_flag = false;
            if(!Mode){ 
               action_flag = true;
            }else{
               string msg;
               if(PositionGetInteger(POSITION_TYPE) == OP_SELL) msg = lang[32];
               else msg = lang[31];
               int accept = MessageBox(msg, lang[25], MB_OKCANCEL);
               if(accept == 1) action_flag = true;
            }
            if(action_flag){
               int ticket = 0;
               do{
                  ticket = trader.PositionClose(PositionGetTicket(pos), 10);
                  if(ticket != true){ 
                     int error = GetLastError();
                     if(error == 132){
                        return 1;
                     }else{
                        if(error_order > 3){
                           Alert(lang[10]+GetLastError());
                           error_order = 0;
                           return brain(server_data);
                        }
                        error_order++;
                     }
                     Sleep(request_delay);
                  }else{
                     error_order = 0;
                  }
               }while(ticket != true);
               return brain(server_data);
            }
         }
      }
   }
   //покупка
   if(buy_signal > 0 && !is_buy){
      bool action_flag = false;
      if(!Mode){ 
         action_flag = true;
      }else{
         string msg = lang[28]+" "+buy_signal+" "+lang[30];
         int accept = MessageBox(msg, lang[25], MB_OKCANCEL);
         if(accept == 1) action_flag = true;
      }
      if(action_flag){
         int ticket = 0;
         do{
            MqlTradeResult result={0}; 
            MqlTradeRequest request={0}; 
            request.action = TRADE_ACTION_DEAL;
            request.symbol = Symbol();
            request.type = ORDER_TYPE_BUY;
            request.comment = id;
            request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
            request.volume = buy_signal;
            request.deviation = 10;
            ticket = OrderSend(request, result);
            if(ticket<0){ 
               int error = GetLastError();
               if(error == 132){
                  return 1;
               }else{
                  if(error_order > 3){
                     Alert(lang[12]+GetLastError());
                     error_order = 0;
                     return brain(server_data);
                  }
                  error_order++;
               }
               Sleep(request_delay);
            }else{
               error_order = 0;
            }
         }while(ticket < 0);
      }
   } 
   //продажа
   if(sell_signal > 0 && !is_sell){
      bool action_flag = false;
      if(!Mode){ 
         action_flag = true;
      }else{
         string msg = lang[29]+" "+sell_signal+" "+lang[30];
         int accept = MessageBox(msg, lang[25], MB_OKCANCEL);
         if(accept == 1) action_flag = true;
      }
      if(action_flag){
         int ticket = 0;
         do{
            MqlTradeResult result={0}; 
            MqlTradeRequest request={0}; 
            request.action = TRADE_ACTION_DEAL;
            request.symbol = Symbol();
            request.type = ORDER_TYPE_SELL;
            request.comment = id;
            request.price = SymbolInfoDouble(Symbol(),SYMBOL_BID);
            request.volume = sell_signal;
            request.deviation = 10;
            request.tp = 0;
            request.sl = 0;
            ticket = OrderSend(request, result);
            if(ticket<0){ 
               int error = GetLastError();
               if(error == 132){
                  return 1;
               }else{
                  if(error_order > 3){
                     Alert(lang[12]+GetLastError());
                     error_order = 0;
                     return brain(server_data);
                  }
                  error_order++;
               }
               Sleep(request_delay);
            }else{
               error_order = 0;
            }
         }while(ticket < 0);
      }
   }
   return 1;
}
//+------------------------------------------------------------------+
int OnInit(){
   if(Email != "" && Password != ""){
      int accept = MessageBox(lang[16], lang[17], MB_OKCANCEL);
      if(accept == 2){
         MessageBox(lang[18]);
         return(INIT_FAILED); 
      }else{
         if(brain(NULL)){
            bool res = EventSetTimer(timer_interval);
            if(res){
               MessageBox(lang[13]);
               return(INIT_SUCCEEDED);
            }else{
               MessageBox(lang[23]+GetLastError());
               return(INIT_FAILED); 
            }
         }else{
            MessageBox(lang[14]);
            EventKillTimer();
            return(INIT_FAILED); 
         }
      }
   }else{
      MessageBox(lang[33]);
      return(INIT_FAILED); 
   }
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   EventKillTimer();
}
//+------------------------------------------------------------------+
void OnTimer(){
   if(!is_exec){
      is_exec = true;
      brain(NULL);
      is_exec = false;
   }
}
//+------------------------------------------------------------------+
double OnTester(){
   Print(lang[20]);
   return(0.00);
}
//+------------------------------------------------------------------+