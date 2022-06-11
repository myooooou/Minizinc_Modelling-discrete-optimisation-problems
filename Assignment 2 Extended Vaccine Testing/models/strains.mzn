% strains.mzn
enum VACCINE;  % set of VACCINES available
VACCINE: placebo; % placebo vaccine
constraint forall(v in VACCINE)
                 (assert(placebo <= v, "vaccine \(v) appears before placebo\n"));

int: N; % number of test populations
set of int: POP = 1..N;

int: W; % number of weeks
set of int: WEEK = 1..W;

enum TREATMENT = { WAIT, VAX, PCR, RAT, SAT };
array[TREATMENT] of int: cost;
array[TREATMENT] of int: mintreat;
array[TREATMENT] of int: maxtreat;

%决策
array[POP,WEEK] of var TREATMENT: schedule;
array[POP] of var set of VACCINE: vaccinations;

int: maxvax;
opt bool: stageD;

% %第一种方法
% %每群人WAIT\VAX\PCR\RAT\SAT治疗次数
% array[TREATMENT,POP] of var int : treatTimes;
% treatTimes = [
%                   (t,p): sum(w in WEEK)( schedule[p,w]= t) |  t in TREATMENT, p in POP
% ];
% %给每个人群提供每种治疗的最低限度，不要超过最高限度。
% constraint forall(p in POP, t in TREATMENT)(
%                treatTimes[t,p] >= mintreat[t] /\
%                treatTimes[t,p] <= maxtreat[t]
% );
%之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气
constraint forall(i in POP, treat in TREATMENT)(
            sum(j in WEEK)(schedule[i,j]=treat)<= maxtreat[treat] /\ 
            sum(j in WEEK)(schedule[i,j]=treat)>= mintreat[treat]
);

%第二种方法
%给每个人群提供每种治疗的最低限度，不要超过最高限度。
% constraint forall(p in POP)(
%            (sum(w in WEEK) (schedule[p,w]=WAIT) >= mintreat[WAIT] /\
%            sum(w in WEEK) (schedule[p,w]=WAIT) <= maxtreat[WAIT])
%            /\
%            (sum(w in WEEK) (schedule[p,w]=VAX) >= mintreat[VAX] /\
%            sum(w in WEEK) (schedule[p,w]=VAX) <= maxtreat[VAX])
%            /\
%            (sum(w in WEEK) (schedule[p,w]=PCR) >= mintreat[PCR] /\
%            sum(w in WEEK) (schedule[p,w]=PCR) <= maxtreat[PCR])
%            /\
%            (sum(w in WEEK) (schedule[p,w]=RAT) >= mintreat[RAT] /\
%            sum(w in WEEK) (schedule[p,w]=RAT) <= maxtreat[RAT])
%            /\
%            (sum(w in WEEK) (schedule[p,w]=SAT) >= mintreat[SAT] /\
%            sum(w in WEEK) (schedule[p,w]=SAT) <= maxtreat[SAT])
% );     
           


%Each population gets a different set of vaccinations
include "globals.mzn";
constraint alldifferent(vaccinations);

%一个群体没有接种疫苗
constraint sum(i in POP)(vaccinations[i]={}) =1;

%VAX出现0次或2*n次,n为疫苗种类
constraint forall(i in POP)(
                  if vaccinations[i]={} then sum(w in WEEK)(schedule[i,w]=VAX)=0 
                                        else sum(w in WEEK)(schedule[i,w]=VAX)=2*card(vaccinations[i]) endif
);


%placebo出现一次
constraint sum(i in POP)(vaccinations[i]={placebo})=1;

%In each week at most maxvax populations can get vaccinated
% constraint forall(w in WEEK)(
%                   sum(p in POP) (schedule[p,w]=VAX) <= maxvax
% );
constraint forall(j in WEEK)(sum(i in POP)(schedule[i,j] = VAX ) <=maxvax);


%VAX之后必须要WAIT        
constraint forall(p in POP, w in 1..W-1)(
                  schedule[p,w]  = VAX  -> schedule[p,w+1] = WAIT
);


constraint  forall(p in POP)(%schedule[p,card(WEEK)]!= VAX /\
                             schedule[p,1]!= WAIT /\  %第一个teatment不能是WAIT
                             schedule[p,1]!= PCR
);

% %做完RAT才能PCR 这个想法好像不对
% constraint forall(p in POP)(
%             exists( w1,w2 in WEEK where w1<w2) ( 
%                     (schedule[p,w1]  = RAT  /\ schedule[p,w2] = PCR )\/
%                     (schedule[p,w1]  = RAT  /\ schedule[p,w2] != PCR )\/
%                     (schedule[p,w1]  != RAT  /\ schedule[p,w2] != PCR ))
% );



%做完RAT才能PCR
% constraint forall(p in POP)(
%             sum( w1,w2 in WEEK where w1<w2) ((schedule[p,w1]= PCR)/\(schedule[p,w2]=RAT)) == 0
            
% );
%之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气之气
constraint forall(i in POP, j in 1..W where schedule[i,j]=RAT)( %%%
                if schedule[i,j]= RAT then forall(k in 1..j-1)(schedule[i,k] != PCR)endif
);

var int : totalCost = sum(p in POP, w in WEEK)(cost[schedule[p,w]]);
solve minimize totalCost;

%每个人群组的治疗费用不超过另一个人群组治疗费用的2倍
%定义每个人群的治疗费用
array[POP] of var int: popCost;
constraint forall(i in POP)(
                  popCost[i] =sum(j in 1..W)(cost[schedule[i,j]])
);
%每个人群组的治疗费用不超过另一个人群组治疗费用的2倍
constraint max(popCost) <= min(popCost)*2;

%output["\(sum(p in POP, w in WEEK)(cost[schedule[p,w]]))"];
output["\(totalCost)"]

