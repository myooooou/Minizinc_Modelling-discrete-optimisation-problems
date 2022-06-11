% Building a blast plan
int: W; % width of area
set of int: COL = 1..W;
int: H; % height of area
set of int: ROW = 1..H;
array[ROW,COL] of int: cost;   % cost to blast in spot
array[ROW,COL] of int: reward; % reward for mining here
int: budget;  
int: limit; % max number of blasts;


var int : profit;

array[1..limit] of var 0..W : x;
array[1..limit] of var 0..H : y;


constraint profit =sum(index in 1..limit where x[index]!=0)(sum(j in 1..H,i in 1..W where abs(j-y[index])<=1 /\ abs(i-x[index])<=1)(reward[j,i]))-(sum(i in 1..limit where x[i]!=0)(cost[y[i],x[i]]));
function var int: m() = sum(i in 1..limit)(x[i]!=0);
constraint forall(i in 1..limit where i <= m())(reward[y[i],x[i]] >= 0);
%距离
constraint forall(i in 1..limit,j in 1..limit where i!=j /\ i <= m() /\ j <= m())(abs(x[i]-x[j])+abs(y[i]-y[j])>=3);
constraint forall(i in 1..limit,j in 1..limit where i!=j /\ i <= m() /\ j <= m())((abs(x[i]-x[j])!=2) \/(abs(y[i]-y[j])!=2));
constraint forall(i in 1..limit,j in 1..limit where i!=j /\ i <= m() /\ j <= m())(not((abs(x[i]-x[j])=1)/\(abs(y[i]-y[j])=2))/\not((abs(x[i]-x[j])=2)/\(abs(y[i]-y[j])=1)));
%limit所有的x[i]都有值
%constraint forall(i in 1..limit)(x[i]!=0);
%没有重复的点
constraint forall(i in 1..limit - 1,j in i+1..limit where i <= m())((x[i]!=x[j]) \/ (y[i]!=y[j]));
%没有reward小于0的点
constraint forall(index in 1..limit,j in 1..H,i in 1..W where reward[j,i]<0/\index<=m())(x[index]!=i \/ y[index]!=j);
%预算
constraint sum(i in 1..limit where i <= m())(cost[y[i],x[i]]) <= budget;
constraint forall(i in 1..limit)(if i>m()then x[i]=0 endif);
constraint forall(i in 1..limit)(if i>m()then y[i]=0 endif);
solve maximize profit;