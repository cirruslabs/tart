// Generated from Reference.g4 by ANTLR 4.13.2
import Antlr4

open class ReferenceLexer: Lexer {

	internal static var _decisionToDFA: [DFA] = {
          var decisionToDFA = [DFA]()
          let length = ReferenceLexer._ATN.getNumberOfDecisions()
          for i in 0..<length {
          	    decisionToDFA.append(DFA(ReferenceLexer._ATN.getDecisionState(i)!, i))
          }
           return decisionToDFA
     }()

	internal static let _sharedContextCache = PredictionContextCache()

	public
	static let T__0=1, T__1=2, T__2=3, T__3=4, T__4=5, T__5=6, DIGIT=7, LETTER=8

	public
	static let channelNames: [String] = [
		"DEFAULT_TOKEN_CHANNEL", "HIDDEN"
	]

	public
	static let modeNames: [String] = [
		"DEFAULT_MODE"
	]

	public
	static let ruleNames: [String] = [
		"T__0", "T__1", "T__2", "T__3", "T__4", "T__5", "DIGIT", "LETTER"
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
	func getVocabulary() -> Vocabulary {
		return ReferenceLexer.VOCABULARY
	}

	public
	required init(_ input: CharStream) {
	    RuntimeMetaData.checkVersion("4.13.2", RuntimeMetaData.VERSION)
		super.init(input)
		_interp = LexerATNSimulator(self, ReferenceLexer._ATN, ReferenceLexer._decisionToDFA, ReferenceLexer._sharedContextCache)
	}

	override open
	func getGrammarFileName() -> String { return "Reference.g4" }

	override open
	func getRuleNames() -> [String] { return ReferenceLexer.ruleNames }

	override open
	func getSerializedATN() -> [Int] { return ReferenceLexer._serializedATN }

	override open
	func getChannelNames() -> [String] { return ReferenceLexer.channelNames }

	override open
	func getModeNames() -> [String] { return ReferenceLexer.modeNames }

	override open
	func getATN() -> ATN { return ReferenceLexer._ATN }

	static let _serializedATN:[Int] = [
		4,0,8,33,6,-1,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,7,6,
		2,7,7,7,1,0,1,0,1,1,1,1,1,2,1,2,1,3,1,3,1,4,1,4,1,5,1,5,1,6,1,6,1,7,1,
		7,0,0,8,1,1,3,2,5,3,7,4,9,5,11,6,13,7,15,8,1,0,2,1,0,48,57,2,0,65,90,97,
		122,32,0,1,1,0,0,0,0,3,1,0,0,0,0,5,1,0,0,0,0,7,1,0,0,0,0,9,1,0,0,0,0,11,
		1,0,0,0,0,13,1,0,0,0,0,15,1,0,0,0,1,17,1,0,0,0,3,19,1,0,0,0,5,21,1,0,0,
		0,7,23,1,0,0,0,9,25,1,0,0,0,11,27,1,0,0,0,13,29,1,0,0,0,15,31,1,0,0,0,
		17,18,5,58,0,0,18,2,1,0,0,0,19,20,5,47,0,0,20,4,1,0,0,0,21,22,5,46,0,0,
		22,6,1,0,0,0,23,24,5,45,0,0,24,8,1,0,0,0,25,26,5,64,0,0,26,10,1,0,0,0,
		27,28,5,95,0,0,28,12,1,0,0,0,29,30,7,0,0,0,30,14,1,0,0,0,31,32,7,1,0,0,
		32,16,1,0,0,0,1,0,0
	]

	public
	static let _ATN: ATN = try! ATNDeserializer().deserialize(_serializedATN)
}