//+------------------------------------------------------------------+
//|                                                Brain Project.mq4 |
//|                                    Copyright 2018, Brain Project |
//+------------------------------------------------------------------+
#property strict
//+------------------------------------------------------------------+
input string   Email = "";
input string   Password = "";
enum confirm{ Automatic, SemiAutomatic };
input confirm  Mode = Automatic;
string url = "https://{api_url}";
//+------------------------------------------------------------------+
int error_connect = 0;
int error_order = 0;
int timer_interval = 60;
int request_delay = 5000;
bool exec = false;
double version = 1.82;
int last_signal = -1;
string id = "Brain Project "+version;
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
   double api_version = StrToDouble(data[0]);
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
   double buy_signal = StrToInteger(data[2]);
   double sell_signal = StrToInteger(data[3]);
   bool is_buy = false;
   bool is_sell = false;
   double lot = MarketInfo(Symbol(), MODE_MINLOT);
   if(AccountInfoString(ACCOUNT_CURRENCY) == "USD"){
      lot = (AccountBalance()/100000);
   }else if(AccountInfoString(ACCOUNT_CURRENCY) == "EUR"){
      lot = ((AccountBalance()/100000)*Ask);
   }else{
      lot = MarketInfo(Symbol(), MODE_MINLOT);
   }
   if(lot < MarketInfo(Symbol(), MODE_MINLOT)){
      lot = MarketInfo(Symbol(), MODE_MINLOT);
   }else if(lot > MarketInfo(Symbol(), MODE_MAXLOT)){
      lot = MarketInfo(Symbol(), MODE_MAXLOT);
   }else{
      double mod = MarketInfo(Symbol(), MODE_LOTSTEP);
      lot = mod * MathRound(lot/mod);
   }
   buy_signal *= lot;
   sell_signal *= lot;
   double price;
   int total = OrdersTotal();
   for(int pos=0; pos<total; pos++){
      bool order_select = FALSE;
      do{
         order_select = OrderSelect(pos, SELECT_BY_POS, MODE_TRADES);
         if(order_select != TRUE){
            if(error_order > 3){
               Alert(lang[19]+GetLastError());
               error_order = 0;
            }
            error_order++;
            Sleep(request_delay);
         }else{
            error_order = 0;
         }
      }while(order_select != TRUE);
      if(StringSubstr(OrderComment(), 0, 18) == id && OrderSymbol() == Symbol()){
         if(OrderType() == OP_BUY){
            is_buy = true;
         }else{
            is_sell = true;
         }
         if((OrderType() == OP_BUY && buy_signal != OrderLots() || 
            (OrderType() == OP_SELL && sell_signal != OrderLots()))){
            bool action_flag = false;
            if(!Mode){ 
               action_flag = true;
            }else{
               string msg;
               if(OrderType() == OP_SELL) msg = lang[32];
               else msg = lang[31];
               int accept = MessageBox(msg, lang[25], MB_OKCANCEL);
               if(accept == 1) action_flag = true;
            }
            if(action_flag){
               int ticket = 0;
               do{
                  RefreshRates();
                  if(OrderType() == OP_SELL){
                     price = Ask;
                  }else{
                     price = Bid;
                  }
                  ticket = OrderClose(OrderTicket(), OrderLots(), price, 10); 
                  if(ticket != TRUE){ 
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
               }while(ticket != TRUE);
               return brain(server_data);
            }
         }
      }
   }
   //покупка
   if(buy_signal > 0 && !is_buy){
   Print("this");
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
            RefreshRates();
            ticket = OrderSend(Symbol(), OP_BUY, buy_signal, Ask, 10, 0, 0, id, 0, 0, clrGreen);
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
            RefreshRates();
            ticket = OrderSend(Symbol(), OP_SELL, sell_signal, Bid, 10, 0, 0, id, 0, 0, clrRed);
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
   if(!exec){
      exec = true;
      brain(NULL);
      exec = false;
   }
}
//+------------------------------------------------------------------+
double OnTester(){
   Print(lang[20]);
   return(0.00);
}
//+------------------------------------------------------------------+