#include <Arrays\Tree.mqh>
#include "OrderNode.mqh"
#include <Arrays\TreeNode.mqh>

class TreeOrder: public CTree{
public:
    OrderNode* findByGrid(double gridStep);
    virtual CTreeNode* CreateElement();
};

CTreeNode* TreeOrder::CreateElement(){
    OrderNode *node = new OrderNode;
    return node;
}

OrderNode* TreeOrder::findByGrid(double gridStep){
    OrderNode *res = NULL;
    OrderNode *node;

    node = new OrderNode;
    if(node==NULL) return NULL;

    node.setGridStep(gridStep);
    Print("node : ",node.getGridStep());
    res = Find(node);
    Print("res : ",res.getGridStep());
    delete node;
    return res;
}

