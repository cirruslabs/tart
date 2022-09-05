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
            RULE_reference = 4, RULE_tag = 5, RULE_tag_separator = 6, RULE_name = 7

	public
	static let ruleNames: [String] = [
		"root", "host", "port", "namespace", "reference", "tag", "tag_separator", 
		"name"
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
		 	setState(16)
		 	try host()
		 	setState(19)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__0.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(17)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(18)
		 		try port()

		 	}

		 	setState(21)
		 	try match(ReferenceParser.Tokens.T__1.rawValue)
		 	setState(22)
		 	try namespace()
		 	setState(24)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	if (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__0.rawValue || _la == ReferenceParser.Tokens.T__3.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(23)
		 		try reference()

		 	}

		 	setState(26)
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
		 	setState(28)
		 	try name()
		 	setState(33)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__2.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(29)
		 		try match(ReferenceParser.Tokens.T__2.rawValue)
		 		setState(30)
		 		try name()


		 		setState(35)
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
		 	setState(37) 
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	repeat {
		 		setState(36)
		 		try match(ReferenceParser.Tokens.DIGIT.rawValue)


		 		setState(39); 
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
			func name() -> [NameContext] {
				return getRuleContexts(NameContext.self)
			}
			open
			func name(_ i: Int) -> NameContext? {
				return getRuleContext(NameContext.self, i)
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
		 	setState(41)
		 	try name()
		 	setState(46)
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	while (//closure
		 	 { () -> Bool in
		 	      let testSet: Bool = _la == ReferenceParser.Tokens.T__1.rawValue
		 	      return testSet
		 	 }()) {
		 		setState(42)
		 		try match(ReferenceParser.Tokens.T__1.rawValue)
		 		setState(43)
		 		try name()


		 		setState(48)
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
		try enterRule(_localctx, 8, ReferenceParser.RULE_reference)
		defer {
	    		try! exitRule()
	    }
		do {
		 	setState(56)
		 	try _errHandler.sync(self)
		 	switch (ReferenceParser.Tokens(rawValue: try _input.LA(1))!) {
		 	case .T__0:
		 		try enterOuterAlt(_localctx, 1)
		 		setState(49)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(50)
		 		try tag()


		 		break

		 	case .T__3:
		 		try enterOuterAlt(_localctx, 2)
		 		setState(51)
		 		try match(ReferenceParser.Tokens.T__3.rawValue)
		 		setState(52)
		 		try name()
		 		setState(53)
		 		try match(ReferenceParser.Tokens.T__0.rawValue)
		 		setState(54)
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
			func tag_separator() -> [Tag_separatorContext] {
				return getRuleContexts(Tag_separatorContext.self)
			}
			open
			func tag_separator(_ i: Int) -> Tag_separatorContext? {
				return getRuleContext(Tag_separatorContext.self, i)
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
		try enterRule(_localctx, 10, ReferenceParser.RULE_tag)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(58)
		 	try name()
		 	setState(64)
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
		 		setState(59)
		 		try tag_separator()
		 		setState(60)
		 		try name()


		 		setState(66)
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

	public class Tag_separatorContext: ParserRuleContext {
		override open
		func getRuleIndex() -> Int {
			return ReferenceParser.RULE_tag_separator
		}
		override open
		func enterRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.enterTag_separator(self)
			}
		}
		override open
		func exitRule(_ listener: ParseTreeListener) {
			if let listener = listener as? ReferenceListener {
				listener.exitTag_separator(self)
			}
		}
	}
	@discardableResult
	 open func tag_separator() throws -> Tag_separatorContext {
		var _localctx: Tag_separatorContext
		_localctx = Tag_separatorContext(_ctx, getState())
		try enterRule(_localctx, 12, ReferenceParser.RULE_tag_separator)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(67)
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
		try enterRule(_localctx, 14, ReferenceParser.RULE_name)
		var _la: Int = 0
		defer {
	    		try! exitRule()
	    }
		do {
		 	try enterOuterAlt(_localctx, 1)
		 	setState(70) 
		 	try _errHandler.sync(self)
		 	_la = try _input.LA(1)
		 	repeat {
		 		setState(69)
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


		 		setState(72); 
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

	static let _serializedATN:[Int] = [
		4,1,8,75,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,6,2,7,7,
		7,1,0,1,0,1,0,3,0,20,8,0,1,0,1,0,1,0,3,0,25,8,0,1,0,1,0,1,1,1,1,1,1,5,
		1,32,8,1,10,1,12,1,35,9,1,1,2,4,2,38,8,2,11,2,12,2,39,1,3,1,3,1,3,5,3,
		45,8,3,10,3,12,3,48,9,3,1,4,1,4,1,4,1,4,1,4,1,4,1,4,3,4,57,8,4,1,5,1,5,
		1,5,1,5,5,5,63,8,5,10,5,12,5,66,9,5,1,6,1,6,1,7,4,7,71,8,7,11,7,12,7,72,
		1,7,0,0,8,0,2,4,6,8,10,12,14,0,2,2,0,3,3,5,6,1,0,7,8,74,0,16,1,0,0,0,2,
		28,1,0,0,0,4,37,1,0,0,0,6,41,1,0,0,0,8,56,1,0,0,0,10,58,1,0,0,0,12,67,
		1,0,0,0,14,70,1,0,0,0,16,19,3,2,1,0,17,18,5,1,0,0,18,20,3,4,2,0,19,17,
		1,0,0,0,19,20,1,0,0,0,20,21,1,0,0,0,21,22,5,2,0,0,22,24,3,6,3,0,23,25,
		3,8,4,0,24,23,1,0,0,0,24,25,1,0,0,0,25,26,1,0,0,0,26,27,5,0,0,1,27,1,1,
		0,0,0,28,33,3,14,7,0,29,30,5,3,0,0,30,32,3,14,7,0,31,29,1,0,0,0,32,35,
		1,0,0,0,33,31,1,0,0,0,33,34,1,0,0,0,34,3,1,0,0,0,35,33,1,0,0,0,36,38,5,
		7,0,0,37,36,1,0,0,0,38,39,1,0,0,0,39,37,1,0,0,0,39,40,1,0,0,0,40,5,1,0,
		0,0,41,46,3,14,7,0,42,43,5,2,0,0,43,45,3,14,7,0,44,42,1,0,0,0,45,48,1,
		0,0,0,46,44,1,0,0,0,46,47,1,0,0,0,47,7,1,0,0,0,48,46,1,0,0,0,49,50,5,1,
		0,0,50,57,3,10,5,0,51,52,5,4,0,0,52,53,3,14,7,0,53,54,5,1,0,0,54,55,3,
		14,7,0,55,57,1,0,0,0,56,49,1,0,0,0,56,51,1,0,0,0,57,9,1,0,0,0,58,64,3,
		14,7,0,59,60,3,12,6,0,60,61,3,14,7,0,61,63,1,0,0,0,62,59,1,0,0,0,63,66,
		1,0,0,0,64,62,1,0,0,0,64,65,1,0,0,0,65,11,1,0,0,0,66,64,1,0,0,0,67,68,
		7,0,0,0,68,13,1,0,0,0,69,71,7,1,0,0,70,69,1,0,0,0,71,72,1,0,0,0,72,70,
		1,0,0,0,72,73,1,0,0,0,73,15,1,0,0,0,8,19,24,33,39,46,56,64,72
	]

	public
	static let _ATN = try! ATNDeserializer().deserialize(_serializedATN)
}