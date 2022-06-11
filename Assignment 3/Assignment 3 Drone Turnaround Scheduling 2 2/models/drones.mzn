enum ACTION = { LAND, INSPECT, FULLSERVICE, RECHARGE, PACK, TAKEOFF };
array[ACTION] of int: resources; % number of machines for each service

int: horizon;  % end time of planning horizon
set of int: TIME = 0..horizon;

int: norders;                    % number of orders;
set of int: ORDER = 1..norders; 
array[ORDER] of int:  dist;      % distance warehouse to delivery         
enum WC = { ULTRA, LIGHT, MEDIUM, HEAVY };         
array[ORDER] of WC:  weight;     % weight catgeory of order
array[ORDER] of TIME: available; % when the order can be packed
array[ORDER] of int:  value;     % value of order
int: ndrones;
set of int: DRONE = 1..ndrones;
array[DRONE] of TIME: arrival;  % when they arrive back
array[DRONE] of int: charge;    % how much charge they have left
array[WC] of int: packtime;

/* Decisions */
array[DRONE, ACTION] of var TIME: start;               % start time for each action  
array[DRONE, ACTION] of var 0..max(resources): resource;  % resource used for each action 
array[DRONE] of var 0..norders: order; % which order given to drone
array[DRONE] of var bool: fastcharge;



% The actions for each drone occur in the specified order after its arrival
% constraint forall(d in DRONE)(start[d,LAND]<start[d,INSPECT]/\
%                                start[d,INSPECT]<start[d,FULLSERVICE]/\
%                                start[d,FULLSERVICE]<=start[d,RECHARGE]/\
%                                start[d,RECHARGE]<start[d,PACK]/\
%                                start[d,PACK]<start[d,TAKEOFF]
%                               );
                              
%Each drone and each action is assigned to a resource that actually exists in the warehouse (if
%the action is used) or 0 otherwise.
%每个无人机和每个操作都分配给仓库中实际存在的资源（如果使用该操作），否则为0。 



%Each order is assigned to at most one drone.
%意味着每个无人机不能有两份相同的订单
include "alldifferent.mzn";
constraint alldifferent(order);


%If the drone is given an order, then it must be assigned a resource for all actions, even if someof them may have 0 duration.
% If it has no order it only should be assigned a resource for LAND and INSPECT actions.
%如果无人机收到命令，则必须为其分配所有操作的资源，即使其中一些操作的持续时间可能为0。如果没有命令，则只应为其分配土地资源并检查行动。 
%ACTION理论上是只能做一次或者0次,除了充电可以有多次
constraint forall(d in DRONE)(
                  if order[d] = 0 
                  then resource[d,LAND] <= resources[LAND] /\ 
                       resource[d,INSPECT] <= resources[INSPECT] /\ 
                       resource[d,FULLSERVICE] = 0 /\ 
                       resource[d,RECHARGE]=0 /\
                       resource[d,PACK] = 0 /\
                       resource[d,TAKEOFF] = 0
                  else forall(a in ACTION )(resource[d,a] <= resources[a] ) 
                  endif
);
%每个无人机的action分配到n个资源 n = resource[d,a]，start后就做几次action
%constraint forall(d in DRONE,a in ACTION)( start[d,a]) = resource[d,a]      
%);

%每个无人机在一条传送带上，必须完成一系列的action
constraint forall(d in DRONE)( if order[d] != 0  
                               then start[d,TAKEOFF] <= horizon
                               else start[d,INSPECT] <= horizon
                               endif
            );


%There are never more actions of any type running than the number of resources for that task;
%ACTION资源限制,在每一个时刻检查资源是否在限制范围内
constraint forall(t in TIME)(
                  forall(a in ACTION)(
                         sum(d in DRONE)(start[d,a] = t) <= resources[a]
                  )
            );

                        
%StageB There is no overlap in actions assigned to the same resource.
%如果两个飞机某时刻都需要使用同一个资源，则需要分配不同的资源id
constraint forall(a in ACTION)(
                  forall(d1,d2 in DRONE where  d1 != d2  /\ start[d1,a] = start[d2,a])(
                      resource[d1,a] != resource[d2,a]
                  )
            );
constraint forall(a in ACTION where a != TAKEOFF)(
                  forall(d1,d2 in DRONE where  d1 != d2  /\ 
                         start[d1,a] < start[d2,enum_next(ACTION,a)] /\
                         start[d2,a] < start[d1,enum_next(ACTION,a)])(
                      resource[d1,a] != resource[d2,a]
                  )
            );

%如果要用同一个资源R，先使用资源R的无人机d1的下一个action需要早于后使用资源R的无人机d2的当前action
constraint forall(a in ACTION where a != TAKEOFF)(
                 forall(d1,d2 in DRONE where d1 != d2 /\ resource[d1,a] = resource[d2,a] ) %需要使用统一资源
                      (start[d1,enum_next(ACTION,a)] >= start[d2,LAND] \/ 
                       start[d2,enum_next(ACTION,a)] >= start[d1,LAND]
                  )
           );

% Each drone doesnt land before its arrival time
constraint forall(d in DRONE)(start[d,LAND] >= arrival[d]);

% An order is not packed before it is available.
constraint forall(d in DRONE)(available[order[d]] <= start[d,PACK]);

% StageC 
% The packing time for the drone depends on the weight of the order it will carry, given by the data
constraint forall(d in DRONE)(start[d,PACK] + packtime[weight[order[d]]] = start[d,TAKEOFF]);

% StageC                             
%The charging time depends on the current charge level and the distance for the order it will
%carry. If the charge level is 10 then it doesnt need recharging, if the charge level is 5 or above
%and the distance at most 50km then it doesnt need recharging, otherwise it needs recharging.
%There are choices on the charging method: fastcharging takes 1 time unit, while slow charging
%takes 4 time units. We need to record the fastcharge decisions for each drone
%forall（where）判断是否要充电，当前电量，order的距离
%充电时间取决于当前充电水平和它将承载的订单的距离。如果充电水平为10，则不需要充电；
%如果充电水平为5或以上，且距离最多为50公里，则不需要充电，否则需要充电。
%充电方式有多种选择：快速充电需要1个时间单位，而慢速充电需要4个时间单位。我们需要记录每架无人机的快速充电决策。 
%if判断是否要快充
%当前电量，order的距离，时间不够，
%操作start packer的时间，向后推1，fast加一个true ，资源id控制
%else 操作start packer的时间，向后推4，资源id控制
constraint forall(d in DRONE)(
                  if (charge[d]=10)/\(order[d]!=0)  %充电水平为10，则不需要充电
                  then (start[d,RECHARGE]=start[d,PACK]) /\ %不需要充电
                       (resource[d,RECHARGE]!=0)  
                  elseif (charge[d]>=5)/\(order[d] != 0)/\(dist[order[d]]<=50) %如果充电水平为5或以上，且距离最多为50公里
                  then  (start[d,RECHARGE]=start[d,PACK]) /\ %不需要充电
                       (resource[d,RECHARGE]!=0)
                  elseif(order[d] != 0)/\((start[d,RECHARGE]+packtime[weight[order[d]]]+4)> horizon) %判断是否要快充
                  %算上打包时间和慢充时间超过最大限制就用快充
                  then (start[d,RECHARGE]+1=start[d,PACK])/\
                        fastcharge[d]=true
                  else (start[d,RECHARGE]+4=start[d,PACK])
                  endif
);
% StageC 
% A full service is required if the charge level is zero, and the next order is HEAVY or MEDIUM
%(so there is a next order); or if the inspection shows some problems. A full service requires
%10 time units. For now we assume the inspection always passes.
%如果收费水平为零，并且下一个订单是重订单或中订单（因此有下一个订单），则需要提供全面服务；
%或者如果检查发现一些问题。完整服务需要10个时间单位。
constraint forall(d in DRONE)(start[d,FULLSERVICE]=start[d,RECHARGE]);

% StageD
%Profit is given by the sum of the value of the orders that have taken
%off by the horizon time. The only cost we calculate is given by the number of fastcharges which
%each cost 5.
%profit=sum（利润）-fast*5
%时间优化=所有飞机的起飞时间-到达时间

var int: obj1; 
constraint obj1 = sum(d in DRONE where(order[d] != 0))(value[order[d]])-sum(d in DRONE where(fastcharge[d]=true))(5);


% StageD
%The secondary objective is to minimize total turn around time, that is the total time
%spent before the drones take off with another order. The turnaround time for a drone is the take
%off time minus the arrival time. If a drone doesnt take an order its turn around time is 0.

var int: obj2; 
constraint obj2 = sum(d in DRONE where(order[d] != 0))(start[d,TAKEOFF]-arrival[d]);

solve maximize (obj1*100 - obj2); 


