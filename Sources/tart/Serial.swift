//
//  File.swift
//  
//
//  Created by Peter Nguyen on 19/12/2022.
//

import Foundation

func createPTY() -> Int32
{
  var tty_fd: Int32 = -1
  var sfd: Int32 = -1
  var termios_ = termios()
  let tty_path = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
    
  var res = openpty(&tty_fd, &sfd, tty_path, &termios_, nil);
  if(res < 0 ){
    perror("openpty error")
    return -1
  }
        
  cfmakeraw(&termios_)
  if(tcsetattr(sfd, TCSANOW, &termios_) != 0){
    perror("tcsetattr error")
    return -1
  }
    
  close(sfd)
        
  res = fcntl(tty_fd, F_GETFL)
  if(res < 0){
    perror("fcntl F_GETFL error")
    return res
  }
    
  res = fcntl(tty_fd, F_SETFL, res | O_NONBLOCK)
  if(res < 0){
    perror("fcntl F_SETFL O_NONBLOCK error")
    return res
  }
    
  print("Successfully open pty \(String(cString: tty_path))")
    
  tty_path.deallocate()
  return tty_fd
}
