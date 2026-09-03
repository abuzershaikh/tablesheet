#ifndef SPREADSHEET_PARSER_H
#define SPREADSHEET_PARSER_H

#include "ast.h"
#include <string>
#include <vector>

struct Token {
    TokenType type;
    std::string lexeme;
    int position;
};

class Tokenizer {
public:
    explicit Tokenizer(std::string src) : source(std::move(src)), pos(0) {}
    std::vector<Token> tokenize();

private:
    std::string source;
    int pos;

    bool isAtEnd() const;
    char currentChar() const;
    void advance();
    bool isDigit(char c) const;
    bool isAlpha(char c) const;

    Token scanNumber();
    Token scanIdentifier();
    Token scanString();
    Token scanSheetName();
    Token scanError();
};

class Parser {
public:
    explicit Parser(std::vector<Token> tks) : tokens(std::move(tks)), pos(0) {}
    std::unique_ptr<ASTNode> parse();

private:
    std::vector<Token> tokens;
    int pos;

    Token current() const;
    Token previous() const;
    bool isAtEnd() const;
    void advance();
    bool match(TokenType type);
    void consume(TokenType type, const std::string& message);
    int getPrecedence(TokenType type) const;

    std::unique_ptr<ASTNode> parseExpression(int precedence);
    std::unique_ptr<ASTNode> parsePrefix();
};

#endif // SPREADSHEET_PARSER_H
