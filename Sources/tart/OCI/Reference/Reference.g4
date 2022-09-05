grammar Reference;

root: host (':' port)? '/' namespace reference? EOF;
host: name ('.' name)*;
port: DIGIT+;
namespace: name ('/' name)*;
reference: (':' tag) | ('@' name ':' name);
tag: name (tag_separator name)*;
tag_separator: '.' | '-' | '_';
name: (LETTER | DIGIT)+;
DIGIT: [0-9];
LETTER: [A-Za-z];
