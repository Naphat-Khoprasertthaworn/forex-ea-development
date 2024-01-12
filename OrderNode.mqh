
#include <Arrays\TreeNode.mqh>

class OrderNode : public CTreeNode{
protected:
    ulong ticketId;
    double gridStep;
public:
    OrderNode();

    ulong getTicketId(void);
    void setTicketId(ulong ticketId);
    double getGridStep(void);
    void setGridStep(double gridStep);

    virtual bool Save(const int file_handle);
    virtual bool Load(const int file_handle);
protected:
    virtual int Compare(const CObject *node,int mode);
    virtual CTreeNode* CreateSimple();
};

OrderNode::OrderNode(){
    this.ticketId = 0;
    this.gridStep = 0;
}

ulong OrderNode::getTicketId(void){
    return this.ticketId;
}

void OrderNode::setTicketId(ulong inpTicketId){
    ticketId = inpTicketId;
}

double OrderNode::getGridStep(void){
    return this.gridStep;
}

void OrderNode::setGridStep(double inpGridStep){
    gridStep = inpGridStep;
}

bool OrderNode::Save(int file_handle){
   uint i=0;
   if(file_handle<0) return(false);

   if(FileWriteLong(file_handle,ticketId)!=sizeof(long))          return(false);

   if(FileWriteDouble(file_handle,gridStep)!=sizeof(double))    return(false);

   return(true);
}

bool OrderNode::Load(int file_handle){
   uint i=0,len;

   if(file_handle<0) return(false);

   if(FileIsEnding(file_handle)) return(false);

   ticketId=FileReadLong(file_handle);

   gridStep=FileReadDouble(file_handle);

   len=FileReadInteger(file_handle,INT_VALUE);

   return(true);
}

CTreeNode* OrderNode::CreateSimple(){
    OrderNode *node = new OrderNode();
    return node;
}

int OrderNode::Compare(const CObject *node,int mode){
    int res = 0;
    OrderNode *n = (OrderNode*)node;
    if(gridStep > n.getGridStep()){
        res = 1;
    }else if(gridStep < n.getGridStep()){
        res = -1;
    }else{
        res = 0;
    }
    return res;
}
