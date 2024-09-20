// Generated from Reference.g4 by ANTLR 4.13.2
import Antlr4

open class ReferenceParser: Parser {

	internal static var _decisionToDFA: [DFA] = {
          var decisionToDFA = [DFA]()
          let length = ReferenceParser._ATN.getNumberOfDecisions()
          for i in 0..<length {
            decisionToDFA.append(DFA(ReferenceParser._ATN.getDecisionState(i)!, i))
           }
           return decisionToDFA
     }()

	internal static let _sharedContextCache = PredictionContextCache()

	public
	enum Tokens: Int {
		case EOF = -1, T__0 = 1, T__1 = 2, T__2 = 3, T__3 = 4, T__4 = 5, T__5 = 6, 
                 DIGIT = 7, LETTER = 8
	}

	public
	static let RULE_root = 0, RULE_host = 1, RULE_port = 2, RULE_host_component = 3, 
            RULE_namespace = 4, RULE_namespace_component = 5, RULE_reference = 6, 
            RULE_tag = 7, RULE_separator = 8, RULE_name = 9

	public
	static let ruleNames: [String] = [
		"root", "host", "port", "host_component", "namespace", "namespace_component", 
		"reference", "tag", "separator", "name"
	]

	private static let _LITERAL_NAMES: [String?] = [
		nil, "':'", "'/'", "'.'", "'-'", "'@'", "'_'"
	]
	private static let _SYMBOLIC_NAMES: [String?] = [
		nil, nil, nil, nil, nil, nil, nil, "DIGIT", "LETTER"
	]
	public
	static let VOCABULARY = Vocabulary(_LITERAL_NAMES, _SYMBOLIC_NAMES)

	override open
	func getGrammarFileName() -> String { return "Reference.g4" }

	override open
	func getRuleNames() -> [String] { return ReferenceParser.ruleNames }

	override open
	func getSerializedATN() -> [Int] { return ReferenceParser._serializedATN }

	override open
	func getATN() -> ATN { return ReferenceParser._ATN }


	override open
	func getVocabulary() -> Vocabulary {
	    return ReferenceParser.VOCABULARY
	}

	override public
	init(_ input:TokenStream) throws {
	    RuntimeMetaData.checkVersion("4.13.2", RuntimeMetaData.VERSION)
		try super.init(input)
		_interp = ParserATNSimulator(self,ReferenceParser._ATN,ReferenceParser._decisionToDFA, ReferenceParser._sharedContextCache)
	}


	public class RootContext: ParserRuleContext {
			open
			func host() -> HostContext? {
				return getRuleContext(HostContext.self, 0)
			}
			open
			func namespace() -> NamespaceContext? {
				return getRuleContext(NamespaceContext.self, 0)
			}
			open
			func EOF() -> TerminalNode? {
				return getToken(ReferenceParser.Tokens.EOF.rawValue, 0)
			}
			open
			func port() -> PortContext? {
				return getRuleContext(PortContext.self, 0)
			}
			open
			func reference() -> ReferenceContext? {
				return getRuleContext(ReferenceContext.self, 0)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_root
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterRoot(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitRoot(self)
			}
		}
	}
	@discardableResult
	 open func root() throws -> RootContext {
		var _localctx: RootContext
		_localctx = RootContext(_ctx, getState())
		try enterRule(_localctx, 0, ReferenceParser.RULE_root)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(20)
		 	try host()
		 	setState(23)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (_la == ReferenceParser.Tokens.T__0.rawValue) {
		 		setState(21)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(22)
		 		try port()

		 	}

		 	setState(25)
		 	try match(ReferenceParser.Tokens.T__1.rawValue)
		 	setState(26)
		 	try namespace()
		 	setState(28)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (_la == ReferenceParser.Tokens.T__0.rawValue || _la == ReferenceParser.Tokens.T__4.rawValue) {
		 		setState(27)
		 		try reference()

		 	}

		 	setState(30)
		 	try match(ReferenceParser.Tokens.EOF.rawValue)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class HostContext: ParserRuleContext {
			open
			func host_component() -> [Host_componentContext] {
				return getRuleContexts(Host_componentContext.self)
			}
			open
			func host_component(_ i: Int) -> Host_componentContext? {
				return getRuleContext(Host_componentContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_host
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterHost(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitHost(self)
			}
		}
	}
	@discardableResult
	 open func host() throws -> HostContext {
		var _localctx: HostContext
		_localctx = HostContext(_ctx, getState())
		try enterRule(_localctx, 2, ReferenceParser.RULE_host)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(32)
		 	try host_component()
		 	setState(37)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == ReferenceParser.Tokens.T__2.rawValue) {
		 		setState(33)
		 		try match(ReferenceParser.Tokens.T__2.rawValue)
		 		setState(34)
		 		try host_component()


		 		setState(39)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class PortContext: ParserRuleContext {
			open
			func DIGIT() -> [TerminalNode] {
				return getTokens(ReferenceParser.Tokens.DIGIT.rawValue)
			}
			open
			func DIGIT(_ i:Int) -> TerminalNode? {
				return getToken(ReferenceParser.Tokens.DIGIT.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_port
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterPort(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitPort(self)
			}
		}
	}
	@discardableResult
	 open func port() throws -> PortContext {
		var _localctx: PortContext
		_localctx = PortContext(_ctx, getState())
		try enterRule(_localctx, 4, ReferenceParser.RULE_port)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(41) 
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	repeat {
		 		setState(40)
		 		try match(ReferenceParser.Tokens.DIGIT.rawValue)


		 		setState(43); 
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	} while (_la == ReferenceParser.Tokens.DIGIT.rawValue)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class Host_componentContext: ParserRuleContext {
			open
			func name() -> [NameContext] {
				return getRuleContexts(NameContext.self)
			}
			open
			func name(_ i: Int) -> NameContext? {
				return getRuleContext(NameContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_host_component
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterHost_component(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitHost_component(self)
			}
		}
	}
	@discardableResult
	 open func host_component() throws -> Host_componentContext {
		var _localctx: Host_componentContext
		_localctx = Host_componentContext(_ctx, getState())
		try enterRule(_localctx, 6, ReferenceParser.RULE_host_component)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(45)
		 	try name()
		 	setState(50)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == ReferenceParser.Tokens.T__3.rawValue) {
		 		setState(46)
		 		try match(ReferenceParser.Tokens.T__3.rawValue)
		 		setState(47)
		 		try name()


		 		setState(52)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class NamespaceContext: ParserRuleContext {
			open
			func namespace_component() -> [Namespace_componentContext] {
				return getRuleContexts(Namespace_componentContext.self)
			}
			open
			func namespace_component(_ i: Int) -> Namespace_componentContext? {
				return getRuleContext(Namespace_componentContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_namespace
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterNamespace(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitNamespace(self)
			}
		}
	}
	@discardableResult
	 open func namespace() throws -> NamespaceContext {
		var _localctx: NamespaceContext
		_localctx = NamespaceContext(_ctx, getState())
		try enterRule(_localctx, 8, ReferenceParser.RULE_namespace)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(53)
		 	try namespace_component()
		 	setState(58)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (_la == ReferenceParser.Tokens.T__1.rawValue) {
		 		setState(54)
		 		try match(ReferenceParser.Tokens.T__1.rawValue)
		 		setState(55)
		 		try namespace_component()


		 		setState(60)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class Namespace_componentContext: ParserRuleContext {
			open
			func name() -> [NameContext] {
				return getRuleContexts(NameContext.self)
			}
			open
			func name(_ i: Int) -> NameContext? {
				return getRuleContext(NameContext.self, i)
			}
			open
			func separator() -> [SeparatorContext] {
				return getRuleContexts(SeparatorContext.self)
			}
			open
			func separator(_ i: Int) -> SeparatorContext? {
				return getRuleContext(SeparatorContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_namespace_component
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterNamespace_component(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitNamespace_component(self)
			}
		}
	}
	@discardableResult
	 open func namespace_component() throws -> Namespace_componentContext {
		var _localctx: Namespace_componentContext
		_localctx = Namespace_componentContext(_ctx, getState())
		try enterRule(_localctx, 10, ReferenceParser.RULE_namespace_component)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(65) 
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	repeat {
		 		setState(61)
		 		try name()
		 		setState(63)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		if (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 88) != 0)) {
		 			setState(62)
		 			try separator()

		 		}



		 		setState(67); 
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	} while (_la == ReferenceParser.Tokens.DIGIT.rawValue || _la == ReferenceParser.Tokens.LETTER.rawValue)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class ReferenceContext: ParserRuleContext {
			open
			func tag() -> TagContext? {
				return getRuleContext(TagContext.self, 0)
			}
			open
			func name() -> [NameContext] {
				return getRuleContexts(NameContext.self)
			}
			open
			func name(_ i: Int) -> NameContext? {
				return getRuleContext(NameContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_reference
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterReference(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitReference(self)
			}
		}
	}
	@discardableResult
	 open func reference() throws -> ReferenceContext {
		var _localctx: ReferenceContext
		_localctx = ReferenceContext(_ctx, getState())
		try enterRule(_localctx, 12, ReferenceParser.RULE_reference)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(76)
		 	try _errHandler.sync(self)
		 	switch (ReferenceParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .T__0:
		 		try enterOuterAlt(_localctx, 1)
		 		setState(69)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(70)
		 		try tag()


		 		break

		 	case .T__4:
		 		try enterOuterAlt(_localctx, 2)
		 		setState(71)
		 		try match(ReferenceParser.Tokens.T__4.rawValue)
		 		setState(72)
		 		try name()
		 		setState(73)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(74)
		 		try name()


		 		break
		 	default:
		 		throw ANTLRException.recognition(e: NoViableAltException(self))
		 	}
		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class TagContext: ParserRuleContext {
			open
			func name() -> [NameContext] {
				return getRuleContexts(NameContext.self)
			}
			open
			func name(_ i: Int) -> NameContext? {
				return getRuleContext(NameContext.self, i)
			}
			open
			func separator() -> [SeparatorContext] {
				return getRuleContexts(SeparatorContext.self)
			}
			open
			func separator(_ i: Int) -> SeparatorContext? {
				return getRuleContext(SeparatorContext.self, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_tag
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterTag(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitTag(self)
			}
		}
	}
	@discardableResult
	 open func tag() throws -> TagContext {
		var _localctx: TagContext
		_localctx = TagContext(_ctx, getState())
		try enterRule(_localctx, 14, ReferenceParser.RULE_tag)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(78)
		 	try name()
		 	setState(84)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 88) != 0)) {
		 		setState(79)
		 		try separator()
		 		setState(80)
		 		try name()


		 		setState(86)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class SeparatorContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_separator
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterSeparator(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitSeparator(self)
			}
		}
	}
	@discardableResult
	 open func separator() throws -> SeparatorContext {
		var _localctx: SeparatorContext
		_localctx = SeparatorContext(_ctx, getState())
		try enterRule(_localctx, 16, ReferenceParser.RULE_separator)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(87)
		 	_la = try _input.LA(1)
		 	if (!(((Int64(_la) & ~0x3f) == 0 && ((Int64(1) << _la) & 88) != 0))) {
		 	try _errHandler.recoverInline(self)
		 	}
		 	else {
		 		_errHandler.reportMatch(self)
		 		try consume()
		 	}

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	public class NameContext: ParserRuleContext {
			open
			func LETTER() -> [TerminalNode] {
				return getTokens(ReferenceParser.Tokens.LETTER.rawValue)
			}
			open
			func LETTER(_ i:Int) -> TerminalNode? {
				return getToken(ReferenceParser.Tokens.LETTER.rawValue, i)
			}
			open
			func DIGIT() -> [TerminalNode] {
				return getTokens(ReferenceParser.Tokens.DIGIT.rawValue)
			}
			open
			func DIGIT(_ i:Int) -> TerminalNode? {
				return getToken(ReferenceParser.Tokens.DIGIT.rawValue, i)
			}
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_name
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterName(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitName(self)
			}
		}
	}
	@discardableResult
	 open func name() throws -> NameContext {
		var _localctx: NameContext
		_localctx = NameContext(_ctx, getState())
		try enterRule(_localctx, 18, ReferenceParser.RULE_name)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
			var _alt:Int
		 	try enterOuterAlt(_localctx, 1)
		 	setState(90); 
		 	try _errHandler.sync(self)
		 	_alt = 1;
		 	repeat {
		 		switch (_alt) {
		 		case 1:
		 			setState(89)
		 			_la = try _input.LA(1)
		 			if (!(_la == ReferenceParser.Tokens.DIGIT.rawValue || _la == ReferenceParser.Tokens.LETTER.rawValue)) {
		 			try _errHandler.recoverInline(self)
		 			}
		 			else {
		 				_errHandler.reportMatch(self)
		 				try consume()
		 			}


		 			break
		 		default:
		 			throw ANTLRException.recognition(e: NoViableAltException(self))
		 		}
		 		setState(92); 
		 		try _errHandler.sync(self)
		 		_alt = try getInterpreter().adaptivePredict(_input,10,_ctx)
		 	} while (_alt != 2 && _alt !=  ATN.INVALID_ALT_NUMBER)

		}
		catch ANTLRException.recognition(let re) {
			_localctx.exception = re
			_errHandler.reportError(self, re)
			try _errHandler.recover(self, re)
		}

		return _localctx
	}

	static let _serializedATN:[Int] = [
		4,1,8,95,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,6,2,7,7,
		7,2,8,7,8,2,9,7,9,1,0,1,0,1,0,3,0,24,8,0,1,0,1,0,1,0,3,0,29,8,0,1,0,1,
		0,1,1,1,1,1,1,5,1,36,8,1,10,1,12,1,39,9,1,1,2,4,2,42,8,2,11,2,12,2,43,
		1,3,1,3,1,3,5,3,49,8,3,10,3,12,3,52,9,3,1,4,1,4,1,4,5,4,57,8,4,10,4,12,
		4,60,9,4,1,5,1,5,3,5,64,8,5,4,5,66,8,5,11,5,12,5,67,1,6,1,6,1,6,1,6,1,
		6,1,6,1,6,3,6,77,8,6,1,7,1,7,1,7,1,7,5,7,83,8,7,10,7,12,7,86,9,7,1,8,1,
		8,1,9,4,9,91,8,9,11,9,12,9,92,1,9,0,0,10,0,2,4,6,8,10,12,14,16,18,0,2,
		2,0,3,4,6,6,1,0,7,8,95,0,20,1,0,0,0,2,32,1,0,0,0,4,41,1,0,0,0,6,45,1,0,
		0,0,8,53,1,0,0,0,10,65,1,0,0,0,12,76,1,0,0,0,14,78,1,0,0,0,16,87,1,0,0,
		0,18,90,1,0,0,0,20,23,3,2,1,0,21,22,5,1,0,0,22,24,3,4,2,0,23,21,1,0,0,
		0,23,24,1,0,0,0,24,25,1,0,0,0,25,26,5,2,0,0,26,28,3,8,4,0,27,29,3,12,6,
		0,28,27,1,0,0,0,28,29,1,0,0,0,29,30,1,0,0,0,30,31,5,0,0,1,31,1,1,0,0,0,
		32,37,3,6,3,0,33,34,5,3,0,0,34,36,3,6,3,0,35,33,1,0,0,0,36,39,1,0,0,0,
		37,35,1,0,0,0,37,38,1,0,0,0,38,3,1,0,0,0,39,37,1,0,0,0,40,42,5,7,0,0,41,
		40,1,0,0,0,42,43,1,0,0,0,43,41,1,0,0,0,43,44,1,0,0,0,44,5,1,0,0,0,45,50,
		3,18,9,0,46,47,5,4,0,0,47,49,3,18,9,0,48,46,1,0,0,0,49,52,1,0,0,0,50,48,
		1,0,0,0,50,51,1,0,0,0,51,7,1,0,0,0,52,50,1,0,0,0,53,58,3,10,5,0,54,55,
		5,2,0,0,55,57,3,10,5,0,56,54,1,0,0,0,57,60,1,0,0,0,58,56,1,0,0,0,58,59,
		1,0,0,0,59,9,1,0,0,0,60,58,1,0,0,0,61,63,3,18,9,0,62,64,3,16,8,0,63,62,
		1,0,0,0,63,64,1,0,0,0,64,66,1,0,0,0,65,61,1,0,0,0,66,67,1,0,0,0,67,65,
		1,0,0,0,67,68,1,0,0,0,68,11,1,0,0,0,69,70,5,1,0,0,70,77,3,14,7,0,71,72,
		5,5,0,0,72,73,3,18,9,0,73,74,5,1,0,0,74,75,3,18,9,0,75,77,1,0,0,0,76,69,
		1,0,0,0,76,71,1,0,0,0,77,13,1,0,0,0,78,84,3,18,9,0,79,80,3,16,8,0,80,81,
		3,18,9,0,81,83,1,0,0,0,82,79,1,0,0,0,83,86,1,0,0,0,84,82,1,0,0,0,84,85,
		1,0,0,0,85,15,1,0,0,0,86,84,1,0,0,0,87,88,7,0,0,0,88,17,1,0,0,0,89,91,
		7,1,0,0,90,89,1,0,0,0,91,92,1,0,0,0,92,90,1,0,0,0,92,93,1,0,0,0,93,19,
		1,0,0,0,11,23,28,37,43,50,58,63,67,76,84,92
	]

	public
	static let _ATN = try! ATNDeserializer().deserialize(_serializedATN)
}