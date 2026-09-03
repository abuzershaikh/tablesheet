#include "parser.h"
#include <stdexcept>
#include <cctype>

bool Tokenizer::isAtEnd() const { return pos >= source.length(); }
char Tokenizer::currentChar() const { return isAtEnd() ? '\0' : source[pos]; }
void Tokenizer::advance() { if (!isAtEnd()) pos++; }
bool Tokenizer::isDigit(char c) const { return c >= '0' && c <= '9'; }
bool Tokenizer::isAlpha(char c) const { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }

Token Tokenizer::scanNumber() {
    int start = pos;
    bool hasDot = false, hasE = false;
    while (!isAtEnd()) {
        char c = currentChar();
        if (isDigit(c)) {
            advance();
        } else if (c == '.' && !hasDot && !hasE) {
            hasDot = true;
            advance();
        } else if ((c == 'e' || c == 'E') && !hasE) {
            hasE = true;
            advance();
            if (currentChar() == '+' || currentChar() == '-') advance();
        } else {
            break;
        }
    }
    return {TokenType::NUMBER, source.substr(start, pos - start), start};
}

Token Tokenizer::scanIdentifier() {
    int start = pos;
    while (!isAtEnd() && (isAlpha(currentChar()) || isDigit(currentChar()) || currentChar() == '_' || currentChar() == '$')) {
        advance();
    }
    return {TokenType::IDENTIFIER, source.substr(start, pos - start), start};
}

Token Tokenizer::scanString() {
    int start = pos;
    advance(); // Skip opening "
    std::string result = "";
    while (!isAtEnd()) {
        if (currentChar() == '"') {
            advance();
            if (!isAtEnd() && currentChar() == '"') {
                result += '"';
                advance();
            } else {
                break;
            }
        } else {
            result += currentChar();
            advance();
        }
    }
    return {TokenType::STRING, result, start};
}

Token Tokenizer::scanSheetName() {
    int start = pos;
    advance(); // Skip '
    while (!isAtEnd() && currentChar() != '\'') {
        advance();
    }
    if (!isAtEnd()) advance(); // Skip '
    int len = pos - start;
    if (len >= 2) len -= 2;
    return {TokenType::IDENTIFIER, source.substr(start + 1, len), start};
}

Token Tokenizer::scanError() {
    int start = pos;
    while (!isAtEnd() && currentChar() != ' ' && currentChar() != ',' && currentChar() != ')') {
        advance();
        std::string sub = source.substr(start, pos - start);
        if (sub.back() == '!' || sub.back() == '?') break;
    }
    return {TokenType::ERROR_TOKEN, source.substr(start, pos - start), start};
}

std::vector<Token> Tokenizer::tokenize() {
    std::vector<Token> tks;
    if (!source.empty() && source[0] == '=') {
        advance();
    }

    while (!isAtEnd()) {
        char c = currentChar();
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            advance();
            continue;
        }
        int startPos = pos;
        switch (c) {
            case '+': advance(); tks.push_back({TokenType::PLUS, "+", startPos}); break;
            case '-': advance(); tks.push_back({TokenType::MINUS, "-", startPos}); break;
            case '*': advance(); tks.push_back({TokenType::MULTIPLY, "*", startPos}); break;
            case '/': advance(); tks.push_back({TokenType::DIVIDE, "/", startPos}); break;
            case '^': advance(); tks.push_back({TokenType::POWER, "^", startPos}); break;
            case '%': advance(); tks.push_back({TokenType::PERCENT, "%", startPos}); break;
            case '&': advance(); tks.push_back({TokenType::CONCAT, "&", startPos}); break;
            case '=': advance(); tks.push_back({TokenType::EQUAL, "=", startPos}); break;
            case '<': 
                advance();
                if (currentChar() == '>') { advance(); tks.push_back({TokenType::NOT_EQUAL, "<>", startPos}); }
                else if (currentChar() == '=') { advance(); tks.push_back({TokenType::LESS_THAN_OR_EQUAL, "<=", startPos}); }
                else { tks.push_back({TokenType::LESS_THAN, "<", startPos}); }
                break;
            case '>': 
                advance();
                if (currentChar() == '=') { advance(); tks.push_back({TokenType::GREATER_THAN_OR_EQUAL, ">=", startPos}); }
                else { tks.push_back({TokenType::GREATER_THAN, ">", startPos}); }
                break;
            case '(': advance(); tks.push_back({TokenType::LPAREN, "(", startPos}); break;
            case ')': advance(); tks.push_back({TokenType::RPAREN, ")", startPos}); break;
            case '{': advance(); tks.push_back({TokenType::LBRACE, "{", startPos}); break;
            case '}': advance(); tks.push_back({TokenType::RBRACE, "}", startPos}); break;
            case ',': advance(); tks.push_back({TokenType::COMMA, ",", startPos}); break;
            case ':': advance(); tks.push_back({TokenType::COLON, ":", startPos}); break;
            case ';': advance(); tks.push_back({TokenType::SEMICOLON, ";", startPos}); break;
            case '@': advance(); tks.push_back({TokenType::AT_SIGN, "@", startPos}); break;
            case '"': tks.push_back(scanString()); break;
            case '\'': tks.push_back(scanSheetName()); break;
            case '!': advance(); tks.push_back({TokenType::EXCLAMATION, "!", startPos}); break;
            case '#':
                if (pos + 1 < source.length() && isAlpha(source[pos + 1])) {
                    tks.push_back(scanError());
                } else {
                    advance();
                    tks.push_back({TokenType::HASH, "#", startPos});
                }
                break;
            default:
                if (isDigit(c) || c == '.') {
                    tks.push_back(scanNumber());
                } else if (isAlpha(c) || c == '_' || c == '$') {
                    tks.push_back(scanIdentifier());
                } else {
                    advance();
                }
                break;
        }
    }
    tks.push_back({TokenType::END_OF_FILE, "", pos});
    return tks;
}

Token Parser::current() const { return tokens[pos]; }
Token Parser::previous() const { return tokens[pos > 0 ? pos - 1 : 0]; }
bool Parser::isAtEnd() const { return current().type == TokenType::END_OF_FILE; }
void Parser::advance() { if (!isAtEnd()) pos++; }
bool Parser::match(TokenType type) {
    if (current().type == type) {
        advance();
        return true;
    }
    return false;
}
void Parser::consume(TokenType type, const std::string& message) {
    if (current().type == type) {
        advance();
        return;
    }
    throw std::runtime_error(message);
}

int Parser::getPrecedence(TokenType type) const {
    switch (type) {
        case TokenType::COLON: return 8;  // Highest - Range operator
        case TokenType::PERCENT: 
        case TokenType::HASH: return 7;
        case TokenType::POWER: return 6;  // Excel-compatible precedence
        case TokenType::MULTIPLY:
        case TokenType::DIVIDE: return 5;
        case TokenType::PLUS:
        case TokenType::MINUS: return 4;
        case TokenType::CONCAT: return 3;  // String concat lower than math
        case TokenType::EQUAL:
        case TokenType::NOT_EQUAL:
        case TokenType::LESS_THAN:
        case TokenType::LESS_THAN_OR_EQUAL:
        case TokenType::GREATER_THAN:
        case TokenType::GREATER_THAN_OR_EQUAL: return 2;  // Comparison
        default: return 0;
    }
}

std::unique_ptr<ASTNode> Parser::parse() {
    return parseExpression(0);
}

std::unique_ptr<ASTNode> Parser::parseExpression(int precedence) {
    auto left = parsePrefix();

    while (!isAtEnd() && precedence < getPrecedence(current().type)) {
        TokenType op = current().type;
        advance();

        if (op == TokenType::COLON) {
            std::string leftRef = "";
            std::string rightRef = "";
            std::string sheetName = "";
            
            auto* cellLeft = dynamic_cast<CellReferenceNode*>(left.get());
            auto* numLeft = dynamic_cast<NumberNode*>(left.get());
            if (cellLeft) {
                leftRef = cellLeft->cellName;
                sheetName = cellLeft->sheetName;
            } else if (numLeft) {
                leftRef = std::to_string((int)numLeft->value);
            }
            
            if (!leftRef.empty()) {
                auto right = parseExpression(getPrecedence(op));
                auto* cellRight = dynamic_cast<CellReferenceNode*>(right.get());
                auto* numRight = dynamic_cast<NumberNode*>(right.get());
                if (cellRight) {
                    rightRef = cellRight->cellName;
                } else if (numRight) {
                    rightRef = std::to_string((int)numRight->value);
                }
                
                if (!rightRef.empty()) {
                    left = std::make_unique<RangeReferenceNode>(leftRef, rightRef, sheetName);
                    continue;
                }
            }
            throw std::runtime_error("Invalid range notation");
        } else if (op == TokenType::PERCENT || op == TokenType::HASH) {
            left = std::make_unique<UnaryOpNode>(op, std::move(left));
        } else {
            auto right = parseExpression(getPrecedence(op));
            left = std::make_unique<BinaryOpNode>(std::move(left), op, std::move(right));
        }
    }
    return left;
}

std::unique_ptr<ASTNode> Parser::parsePrefix() {
    if (match(TokenType::PLUS) || match(TokenType::MINUS) || match(TokenType::AT_SIGN)) {
        TokenType op = previous().type;
        auto operand = parseExpression(6);
        return std::make_unique<UnaryOpNode>(op, std::move(operand));
    }

    if (match(TokenType::LPAREN)) {
        auto expr = parseExpression(0);
        consume(TokenType::RPAREN, "Expected ')' after expression");
        return expr;
    }

    if (match(TokenType::NUMBER)) {
        return std::make_unique<NumberNode>(std::stod(previous().lexeme));
    }
    if (match(TokenType::STRING)) {
        return std::make_unique<StringNode>(previous().lexeme);
    }
    if (match(TokenType::ERROR_TOKEN)) {
        return std::make_unique<ErrorNode>(previous().lexeme);
    }
    if (match(TokenType::IDENTIFIER)) {
        std::string name = previous().lexeme;
        std::string sheetName = "";
        
        if (match(TokenType::EXCLAMATION)) {
            sheetName = name;
            if (match(TokenType::IDENTIFIER)) {
                name = previous().lexeme;
            } else {
                throw std::runtime_error("Expected cell reference after '!'");
            }
        }
        
        if (match(TokenType::LPAREN)) {
            std::vector<std::unique_ptr<ASTNode>> args;
            if (current().type != TokenType::RPAREN) {
                do {
                    if (current().type == TokenType::COMMA || current().type == TokenType::RPAREN) {
                        args.push_back(std::make_unique<BlankNode>());
                    } else {
                        args.push_back(parseExpression(0));
                    }
                } while (match(TokenType::COMMA));
            }
            consume(TokenType::RPAREN, "Expected ')' after arguments");
            return std::make_unique<FunctionNode>(name, std::move(args));
        }
        
        // simple upper case check for booleans
        std::string upperName = name;
        for(char &c : upperName) c = toupper(c);
        if (upperName == "TRUE") return std::make_unique<BooleanNode>(true);
        if (upperName == "FALSE") return std::make_unique<BooleanNode>(false);
        
        return std::make_unique<CellReferenceNode>(name, sheetName);
    }
    if (match(TokenType::LBRACE)) {
        std::vector<std::vector<std::unique_ptr<ASTNode>>> rows;
        do {
            std::vector<std::unique_ptr<ASTNode>> row;
            do {
                row.push_back(parseExpression(0));
            } while (match(TokenType::COMMA));
            rows.push_back(std::move(row));
        } while (match(TokenType::SEMICOLON));
        consume(TokenType::RBRACE, "Expected '}' after array");
        return std::make_unique<ArrayNode>(std::move(rows));
    }

    throw std::runtime_error("Unexpected token: " + current().lexeme);
}
