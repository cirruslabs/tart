import Foundation

func createPTY() -> Int32 {
  var tty_fd: Int32 = -1
  var sfd: Int32 = -1
  var termios_ = termios()
  let tty_path = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)

  var res = openpty(&tty_fd, &sfd, tty_path, nil, nil);
  if (res < 0) {
    perror("openpty error")
    return -1
  }

  // close slave file descriptor
  close(sfd)

  res = fcntl(tty_fd, F_GETFL)
  if (res < 0) {
    perror("fcntl F_GETFL error")
    return res
  }

  // set serial nonblocking
  res = fcntl(tty_fd, F_SETFL, res | O_NONBLOCK)
  if (res < 0) {
    perror("fcntl F_SETFL O_NONBLOCK error")
    return res
  }

  // set baudrate to 115200
  tcgetattr(tty_fd, &termios_)
  cfsetispeed(&termios_, speed_t(B115200))
  cfsetospeed(&termios_, speed_t(B115200))
  if (tcsetattr(tty_fd, TCSANOW, &termios_) != 0) {
    perror("tcsetattr error")
    return -1
  }

  print("Successfully open pty \(String(cString: tty_path))")

  tty_path.deallocate()
  return tty_fd
}
