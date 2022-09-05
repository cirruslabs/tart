// Generated from Reference.g4 by ANTLR 4.10.1
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
	static let RULE_root = 0, RULE_host = 1, RULE_port = 2, RULE_namespace = 3, 
            RULE_namespace_component = 4, RULE_reference = 5, RULE_tag = 6, 
            RULE_separator = 7, RULE_name = 8

	public
	static let ruleNames: [String] = [
		"root", "host", "port", "namespace", "namespace_component", "reference", 
		"tag", "separator", "name"
	]

	private static let _LITERAL_NAMES: [String?] = [
		nil, "':'", "'/'", "'.'", "'@'", "'-'", "'_'"
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
	    RuntimeMetaData.checkVersion("4.10.1", RuntimeMetaData.VERSION)
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
		 	setState(18)
		 	try host()
		 	setState(21)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__0.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(19)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(20)
		 		try port()

		 	}

		 	setState(23)
		 	try match(ReferenceParser.Tokens.T__1.rawValue)
		 	setState(24)
		 	try namespace()
		 	setState(26)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__0.rawValue || _la == ReferenceParser.Tokens.T__3.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(25)
		 		try reference()

		 	}

		 	setState(28)
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
			func name() -> [NameContext] {
				return getRuleContexts(NameContext.self)
			}
			open
			func name(_ i: Int) -> NameContext? {
				return getRuleContext(NameContext.self, i)
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
		 	setState(30)
		 	try name()
		 	setState(35)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__2.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(31)
		 		try match(ReferenceParser.Tokens.T__2.rawValue)
		 		setState(32)
		 		try name()


		 		setState(37)
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
		 	setState(39) 
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	repeat {
		 		setState(38)
		 		try match(ReferenceParser.Tokens.DIGIT.rawValue)


		 		setState(41); 
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	} while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.DIGIT.rawValue
		 	      return testSet
		 	 }())

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
		try enterRule(_localctx, 6, ReferenceParser.RULE_namespace)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(43)
		 	try namespace_component()
		 	setState(48)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__1.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(44)
		 		try match(ReferenceParser.Tokens.T__1.rawValue)
		 		setState(45)
		 		try namespace_component()


		 		setState(50)
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
		try enterRule(_localctx, 8, ReferenceParser.RULE_namespace_component)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(55) 
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	repeat {
		 		setState(51)
		 		try name()
		 		setState(53)
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 		if (//closure
		 		 { () -> Bool in
		 		      let testSet: Bool = {  () -> Bool in
		 		   let testArray: [Int] = [_la, ReferenceParser.Tokens.T__2.rawValue,ReferenceParser.Tokens.T__4.rawValue,ReferenceParser.Tokens.T__5.rawValue]
		 		    return  Utils.testBitLeftShiftArray(testArray, 0)
		 		}()
		 		      return testSet
		 		 }()) {
		 			setState(52)
		 			try separator()

		 		}



		 		setState(57); 
		 		try _errHandler.sync(self)
		 		_la = try _input.LA(1)
		 	} while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.DIGIT.rawValue || _la == ReferenceParser.Tokens.LETTER.rawValue
		 	      return testSet
		 	 }())

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
		try enterRule(_localctx, 10, ReferenceParser.RULE_reference)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(66)
		 	try _errHandler.sync(self)
		 	switch (ReferenceParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .T__0:
		 		try enterOuterAlt(_localctx, 1)
		 		setState(59)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(60)
		 		try tag()


		 		break

		 	case .T__3:
		 		try enterOuterAlt(_localctx, 2)
		 		setState(61)
		 		try match(ReferenceParser.Tokens.T__3.rawValue)
		 		setState(62)
		 		try name()
		 		setState(63)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(64)
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
		try enterRule(_localctx, 12, ReferenceParser.RULE_tag)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(68)
		 	try name()
		 	setState(74)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = {  () -> Bool in
		 	   let testArray: [Int] = [_la, ReferenceParser.Tokens.T__2.rawValue,ReferenceParser.Tokens.T__4.rawValue,ReferenceParser.Tokens.T__5.rawValue]
		 	    return  Utils.testBitLeftShiftArray(testArray, 0)
		 	}()
		 	      return testSet
		 	 }()) {
		 		setState(69)
		 		try separator()
		 		setState(70)
		 		try name()


		 		setState(76)
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
		try enterRule(_localctx, 14, ReferenceParser.RULE_separator)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(77)
		 	_la = try _input.LA(1)
		 	if (!(//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = {  () -> Bool in
		 	   let testArray: [Int] = [_la, ReferenceParser.Tokens.T__2.rawValue,ReferenceParser.Tokens.T__4.rawValue,ReferenceParser.Tokens.T__5.rawValue]
		 	    return  Utils.testBitLeftShiftArray(testArray, 0)
		 	}()
		 	      return testSet
		 	 }())) {
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
		try enterRule(_localctx, 16, ReferenceParser.RULE_name)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
			var _alt:Int
		 	try enterOuterAlt(_localctx, 1)
		 	setState(80); 
		 	try _errHandler.sync(self)
		 	_alt = 1;
		 	repeat {
		 		switch (_alt) {
		 		case 1:
		 			setState(79)
		 			_la = try _input.LA(1)
		 			if (!(//closure
		 			 { () -> Bool in
		 			      let testSet: Bool = _la == ReferenceParser.Tokens.DIGIT.rawValue || _la == ReferenceParser.Tokens.LETTER.rawValue
		 			      return testSet
		 			 }())) {
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
		 		setState(82); 
		 		try _errHandler.sync(self)
		 		_alt = try getInterpreter().adaptivePredict(_input,9,_ctx)
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
		4,1,8,85,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,6,2,7,7,
		7,2,8,7,8,1,0,1,0,1,0,3,0,22,8,0,1,0,1,0,1,0,3,0,27,8,0,1,0,1,0,1,1,1,
		1,1,1,5,1,34,8,1,10,1,12,1,37,9,1,1,2,4,2,40,8,2,11,2,12,2,41,1,3,1,3,
		1,3,5,3,47,8,3,10,3,12,3,50,9,3,1,4,1,4,3,4,54,8,4,4,4,56,8,4,11,4,12,
		4,57,1,5,1,5,1,5,1,5,1,5,1,5,1,5,3,5,67,8,5,1,6,1,6,1,6,1,6,5,6,73,8,6,
		10,6,12,6,76,9,6,1,7,1,7,1,8,4,8,81,8,8,11,8,12,8,82,1,8,0,0,9,0,2,4,6,
		8,10,12,14,16,0,2,2,0,3,3,5,6,1,0,7,8,85,0,18,1,0,0,0,2,30,1,0,0,0,4,39,
		1,0,0,0,6,43,1,0,0,0,8,55,1,0,0,0,10,66,1,0,0,0,12,68,1,0,0,0,14,77,1,
		0,0,0,16,80,1,0,0,0,18,21,3,2,1,0,19,20,5,1,0,0,20,22,3,4,2,0,21,19,1,
		0,0,0,21,22,1,0,0,0,22,23,1,0,0,0,23,24,5,2,0,0,24,26,3,6,3,0,25,27,3,
		10,5,0,26,25,1,0,0,0,26,27,1,0,0,0,27,28,1,0,0,0,28,29,5,0,0,1,29,1,1,
		0,0,0,30,35,3,16,8,0,31,32,5,3,0,0,32,34,3,16,8,0,33,31,1,0,0,0,34,37,
		1,0,0,0,35,33,1,0,0,0,35,36,1,0,0,0,36,3,1,0,0,0,37,35,1,0,0,0,38,40,5,
		7,0,0,39,38,1,0,0,0,40,41,1,0,0,0,41,39,1,0,0,0,41,42,1,0,0,0,42,5,1,0,
		0,0,43,48,3,8,4,0,44,45,5,2,0,0,45,47,3,8,4,0,46,44,1,0,0,0,47,50,1,0,
		0,0,48,46,1,0,0,0,48,49,1,0,0,0,49,7,1,0,0,0,50,48,1,0,0,0,51,53,3,16,
		8,0,52,54,3,14,7,0,53,52,1,0,0,0,53,54,1,0,0,0,54,56,1,0,0,0,55,51,1,0,
		0,0,56,57,1,0,0,0,57,55,1,0,0,0,57,58,1,0,0,0,58,9,1,0,0,0,59,60,5,1,0,
		0,60,67,3,12,6,0,61,62,5,4,0,0,62,63,3,16,8,0,63,64,5,1,0,0,64,65,3,16,
		8,0,65,67,1,0,0,0,66,59,1,0,0,0,66,61,1,0,0,0,67,11,1,0,0,0,68,74,3,16,
		8,0,69,70,3,14,7,0,70,71,3,16,8,0,71,73,1,0,0,0,72,69,1,0,0,0,73,76,1,
		0,0,0,74,72,1,0,0,0,74,75,1,0,0,0,75,13,1,0,0,0,76,74,1,0,0,0,77,78,7,
		0,0,0,78,15,1,0,0,0,79,81,7,1,0,0,80,79,1,0,0,0,81,82,1,0,0,0,82,80,1,
		0,0,0,82,83,1,0,0,0,83,17,1,0,0,0,10,21,26,35,41,48,53,57,66,74,82
	]

	public
	static let _ATN = try! ATNDeserializer().deserialize(_serializedATN)
}