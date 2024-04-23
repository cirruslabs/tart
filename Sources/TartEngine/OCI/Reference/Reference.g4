grammar Reference;

root: host (':' port)? '/' namespace reference? EOF;
host: host_component ('.' host_component)*;
port: DIGIT+;
host_component: name ('-' name)*;
namespace: namespace_component ('/' namespace_component)*;
namespace_component: (name separator?)+;
reference: (':' tag) | ('@' name ':' name);
tag: name (separator name)*;
separator: '.' | '-' | '_';
name: (LETTER | DIGIT)+;
DIGIT: [0-9];
LETTER: [A-Za-z];
