#ifndef SPREADSHEET_AST_H
#define SPREADSHEET_AST_H

#include <string>
#include <vector>
#include <memory>
#include <variant>

// Forward declarations
class ASTVisitor;

enum class TokenType {
    NUMBER, STRING, IDENTIFIER, RANGE,
    PLUS, MINUS, MULTIPLY, DIVIDE, POWER, PERCENT, CONCAT,
    EQUAL, NOT_EQUAL, LESS_THAN, LESS_THAN_OR_EQUAL, GREATER_THAN, GREATER_THAN_OR_EQUAL,
    COMMA, COLON, LPAREN, RPAREN, LBRACE, RBRACE, SEMICOLON, AT_SIGN, HASH, EXCLAMATION,
    ERROR_TOKEN, END_OF_FILE
};

class ASTNode {
public:
    virtual ~ASTNode() = default;
    virtual void accept(ASTVisitor& visitor) = 0;
    virtual std::unique_ptr<ASTNode> clone() const = 0;
};

class NumberNode : public ASTNode {
public:
    double value;
    explicit NumberNode(double val) : value(val) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class StringNode : public ASTNode {
public:
    std::string value;
    explicit StringNode(std::string val) : value(std::move(val)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class BooleanNode : public ASTNode {
public:
    bool value;
    explicit BooleanNode(bool val) : value(val) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class ErrorNode : public ASTNode {
public:
    std::string error;
    explicit ErrorNode(std::string err) : error(std::move(err)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class CellReferenceNode : public ASTNode {
public:
    std::string sheetName;
    std::string cellName;
    explicit CellReferenceNode(std::string name, std::string sheet = "") : sheetName(std::move(sheet)), cellName(std::move(name)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class RangeReferenceNode : public ASTNode {
public:
    std::string sheetName;
    std::string topLeft;
    std::string bottomRight;
    RangeReferenceNode(std::string tl, std::string br, std::string sheet = "") : sheetName(std::move(sheet)), topLeft(std::move(tl)), bottomRight(std::move(br)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class BinaryOpNode : public ASTNode {
public:
    std::unique_ptr<ASTNode> left;
    TokenType op;
    std::unique_ptr<ASTNode> right;
    
    BinaryOpNode(std::unique_ptr<ASTNode> l, TokenType o, std::unique_ptr<ASTNode> r) 
        : left(std::move(l)), op(o), right(std::move(r)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class UnaryOpNode : public ASTNode {
public:
    TokenType op;
    std::unique_ptr<ASTNode> operand;
    
    UnaryOpNode(TokenType o, std::unique_ptr<ASTNode> opnd) : op(o), operand(std::move(opnd)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class FunctionNode : public ASTNode {
public:
    std::string name;
    std::vector<std::unique_ptr<ASTNode>> arguments;
    
    FunctionNode(std::string n, std::vector<std::unique_ptr<ASTNode>> args) 
        : name(std::move(n)), arguments(std::move(args)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class ArrayNode : public ASTNode {
public:
    std::vector<std::vector<std::unique_ptr<ASTNode>>> rows;
    explicit ArrayNode(std::vector<std::vector<std::unique_ptr<ASTNode>>> r) : rows(std::move(r)) {}
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class BlankNode : public ASTNode {
public:
    BlankNode() = default;
    void accept(ASTVisitor& visitor) override;
    std::unique_ptr<ASTNode> clone() const override;
};

class ASTVisitor {
public:
    virtual ~ASTVisitor() = default;
    virtual void visit(NumberNode& node) = 0;
    virtual void visit(StringNode& node) = 0;
    virtual void visit(BooleanNode& node) = 0;
    virtual void visit(ErrorNode& node) = 0;
    virtual void visit(CellReferenceNode& node) = 0;
    virtual void visit(RangeReferenceNode& node) = 0;
    virtual void visit(BinaryOpNode& node) = 0;
    virtual void visit(UnaryOpNode& node) = 0;
    virtual void visit(FunctionNode& node) = 0;
    virtual void visit(ArrayNode& node) = 0;
    virtual void visit(BlankNode& node) = 0;
};

#endif // SPREADSHEET_AST_H
