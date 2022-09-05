// Generated from Reference.g4 by ANTLR 4.10.1
import Antlr4

/**
 * This interface defines a complete listener for a parse tree produced by
 * {@link ReferenceParser}.
 */
public protocol ReferenceListener: ParseTreeListener {
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#root}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterRoot(_ ctx: ReferenceParser.RootContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#root}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitRoot(_ ctx: ReferenceParser.RootContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#host}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterHost(_ ctx: ReferenceParser.HostContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#host}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitHost(_ ctx: ReferenceParser.HostContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#port}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterPort(_ ctx: ReferenceParser.PortContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#port}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitPort(_ ctx: ReferenceParser.PortContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#namespace}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterNamespace(_ ctx: ReferenceParser.NamespaceContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#namespace}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitNamespace(_ ctx: ReferenceParser.NamespaceContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#reference}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterReference(_ ctx: ReferenceParser.ReferenceContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#reference}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitReference(_ ctx: ReferenceParser.ReferenceContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#tag}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterTag(_ ctx: ReferenceParser.TagContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#tag}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitTag(_ ctx: ReferenceParser.TagContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#tag_separator}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterTag_separator(_ ctx: ReferenceParser.Tag_separatorContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#tag_separator}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitTag_separator(_ ctx: ReferenceParser.Tag_separatorContext)
	/**
	 * Enter a parse tree produced by {@link ReferenceParser#name}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterName(_ ctx: ReferenceParser.NameContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#name}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitName(_ ctx: ReferenceParser.NameContext)
}