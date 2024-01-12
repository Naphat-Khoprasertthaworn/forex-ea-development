#property copyright "2010, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Math/Stat/Math.mqh>
#include <Generic\HashMap.mqh>

#include <Arrays\Tree.mqh>

#include "ExpertAdvisor.mqh"
#include "OrderNode.mqh"

class TreeOrder: public CTree{
public:
    TreeOrder():CTree(){
        this.root = NULL;
    }
    
    OrderNode* findByGrid(double gridStep){
        OrderNode *res;
        OrderNode *node;

        node = new OrderNode;
        node.gridStep = gridStep
        if(node==NULL) return NULL;

        res = Find(node);
        delete node;
        return res;
    }

    OrderNode* CreateElement(){
        OrderNode *node = new OrderNode(0,0);
        return node;
    }
};

class GMExpert: public ExpertAdvisor{
public:
    TreeOrder *tree;

    GMExpert(long inpType):ExpertAdvisor(inpType){
        this.tree = new TreeOrder();
    };


};

ulong ticketArr[10] = {1,2,3,4,5,6,7,8,9,10};
double gridArr[10]  = {0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9};

GMExpert buyObj(POSITION_TYPE_BUY);

int OnInit(){
    for(int i=0;i<10;i++){
        OrderNode *node = new OrderNode(ticketArr[i],gridArr[i]);
        OrderNode *res;
        res = buyObj.tree.Insert(node);
        if(res==NULL){
            Print("Failed to insert node");
        }else{
            Print("Inserted node");
        }
    }
}