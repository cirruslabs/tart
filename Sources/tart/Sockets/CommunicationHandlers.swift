import NIOCore

// Protocol that allows a delegate to be notified when a channel is closed by the remote peer.
protocol CatchRemoteCloseDelegate {
  func closedByRemote(port: Int)
}

// This is a simple ChannelInboundHandler that catches the event of the remote peer closing the connection.
final class CatchRemoteClose: ChannelInboundHandler {
  typealias InboundIn = Any

  let port: Int
  let delegate: CatchRemoteCloseDelegate

  init(port: Int, delegate: CatchRemoteCloseDelegate) {
    self.port = port
    self.delegate = delegate
  }

  func channelInactive(context: ChannelHandlerContext) {
    context.flush()
    self.delegate.closedByRemote(port: self.port)
    context.fireChannelInactive()
  }
}

// This is a simple ChannelDuplexHandler that glues two channels together.
// It is used to create a forwarder that forwards all data from one channel to another.
final class GlueHandler: ChannelDuplexHandler {
  typealias InboundIn = NIOAny
  typealias OutboundIn = NIOAny
  typealias OutboundOut = NIOAny

  private var partner: GlueHandler?
  private var context: ChannelHandlerContext?
  private var pendingRead: Bool = false

  private init() {
  }

  static func matchedPair() -> (GlueHandler, GlueHandler) {
    let first = GlueHandler()
    let second = GlueHandler()

    first.partner = second
    second.partner = first

    return (first, second)
  }

  private func partnerWrite(_ data: NIOAny) {
    context?.writeAndFlush(data, promise: nil)
  }

  private func partnerFlush() {
    context?.flush()
  }

  private func partnerWriteEOF() {
    context?.flush()
    context?.close(mode: .output, promise: nil)
  }

  private func partnerCloseFull() {
    context?.close(promise: nil)
  }

  private func partnerBecameWritable() {
    if pendingRead {
      pendingRead = false
      context?.read()
    }
  }

  private var partnerWritable: Bool {
    context?.channel.isWritable ?? false
  }

  func handlerAdded(context: ChannelHandlerContext) {
    self.context = context
  }

  func handlerRemoved(context _: ChannelHandlerContext) {
    context = nil
    partner = nil
  }

  func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
    partner?.partnerWrite(data)
  }

  func channelReadComplete(context _: ChannelHandlerContext) {
    partner?.partnerFlush()
  }

  func channelInactive(context _: ChannelHandlerContext) {
    partner?.partnerCloseFull()
  }

  func userInboundEventTriggered(context _: ChannelHandlerContext, event: Any) {
    if let event = event as? ChannelEvent, case .inputClosed = event {
      // We have read EOF.
      partner?.partnerWriteEOF()
    }
  }

  func errorCaught(context _: ChannelHandlerContext, error : Error) {
    defaultLogger.appendNewLine("Error in pipeline: \(error)")
    partner?.partnerCloseFull()
  }

  func channelWritabilityChanged(context: ChannelHandlerContext) {
    if context.channel.isWritable {
      partner?.partnerBecameWritable()
    }
  }

  func read(context: ChannelHandlerContext) {
    if let partner = partner, partner.partnerWritable {
      context.read()
    } else {
      pendingRead = true
    }
  }
}
