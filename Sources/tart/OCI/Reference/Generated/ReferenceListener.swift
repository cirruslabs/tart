// Generated from Reference.g4 by ANTLR 4.13.2
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
	 * Enter a parse tree produced by {@link ReferenceParser#host_component}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterHost_component(_ ctx: ReferenceParser.Host_componentContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#host_component}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitHost_component(_ ctx: ReferenceParser.Host_componentContext)
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
	 * Enter a parse tree produced by {@link ReferenceParser#namespace_component}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterNamespace_component(_ ctx: ReferenceParser.Namespace_componentContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#namespace_component}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitNamespace_component(_ ctx: ReferenceParser.Namespace_componentContext)
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
	 * Enter a parse tree produced by {@link ReferenceParser#separator}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func enterSeparator(_ ctx: ReferenceParser.SeparatorContext)
	/**
	 * Exit a parse tree produced by {@link ReferenceParser#separator}.
	 - Parameters:
	   - ctx: the parse tree
	 */
	func exitSeparator(_ ctx: ReferenceParser.SeparatorContext)
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