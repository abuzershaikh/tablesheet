#include "ast.h"

void NumberNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void StringNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void BooleanNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void ErrorNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void CellReferenceNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void RangeReferenceNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void BinaryOpNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void UnaryOpNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void FunctionNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void ArrayNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }
void BlankNode::accept(ASTVisitor& visitor) { visitor.visit(*this); }

std::unique_ptr<ASTNode> NumberNode::clone() const { return std::make_unique<NumberNode>(value); }
std::unique_ptr<ASTNode> StringNode::clone() const { return std::make_unique<StringNode>(value); }
std::unique_ptr<ASTNode> BooleanNode::clone() const { return std::make_unique<BooleanNode>(value); }
std::unique_ptr<ASTNode> ErrorNode::clone() const { return std::make_unique<ErrorNode>(error); }
std::unique_ptr<ASTNode> CellReferenceNode::clone() const { return std::make_unique<CellReferenceNode>(cellName, sheetName); }
std::unique_ptr<ASTNode> RangeReferenceNode::clone() const { return std::make_unique<RangeReferenceNode>(topLeft, bottomRight, sheetName); }
std::unique_ptr<ASTNode> BinaryOpNode::clone() const { return std::make_unique<BinaryOpNode>(left->clone(), op, right->clone()); }
std::unique_ptr<ASTNode> UnaryOpNode::clone() const { return std::make_unique<UnaryOpNode>(op, operand->clone()); }
std::unique_ptr<ASTNode> FunctionNode::clone() const {
    std::vector<std::unique_ptr<ASTNode>> clonedArgs;
    for (const auto& arg : arguments) clonedArgs.push_back(arg->clone());
    return std::make_unique<FunctionNode>(name, std::move(clonedArgs));
}
std::unique_ptr<ASTNode> ArrayNode::clone() const {
    std::vector<std::vector<std::unique_ptr<ASTNode>>> clonedRows;
    for (const auto& row : rows) {
        std::vector<std::unique_ptr<ASTNode>> clonedRow;
        for (const auto& expr : row) clonedRow.push_back(expr->clone());
        clonedRows.push_back(std::move(clonedRow));
    }
    return std::make_unique<ArrayNode>(std::move(clonedRows));
}
std::unique_ptr<ASTNode> BlankNode::clone() const { return std::make_unique<BlankNode>(); }
