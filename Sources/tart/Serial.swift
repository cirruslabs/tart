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
    var tty_path = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)
    
    let tty_fd_ref = UnsafeMutablePointer<Int32>.init(&tty_fd)
    let sfd_ref = UnsafeMutablePointer<Int32>.init(&sfd)
    let termios_ref = UnsafeMutablePointer<termios>.init(&termios_)
    let unused_ref = UnsafeMutablePointer<winsize>.init(nil)
    
    var res = openpty(tty_fd_ref, sfd_ref, tty_path, termios_ref, unused_ref);
    if(res < 0 ){
        perror("openpty error")
        return -1
    }
    
    cfmakeraw(termios_ref)
    if(tcsetattr(sfd, TCSAFLUSH, termios_ref) != 0){
        perror("tcsetattr error")
        return -1
    }
    
    close(sfd)
    
    res = fcntl(tty_fd, F_GETFL)
    fcntl(tty_fd, F_SETFL, res | O_NONBLOCK)
    
    print("Successfully open pty \(String(cString: tty_path))")
    
    tty_path.deallocate()
    return tty_fd
}
