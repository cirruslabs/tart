package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/mdlayher/vsock"
)

const (
	vsockPort = 9999
)

func echoHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPost {
		if body, err := io.ReadAll(r.Body); err != nil {
			http.Error(w, "Failed to read request body", http.StatusInternalServerError)
		} else {
			defer r.Body.Close()

			w.Write(body)
		}
	} else {
		http.Error(w, "Invalid request method", http.StatusMethodNotAllowed)
	}
}

func writePidToFile(filePath string) error {
	pid := os.Getpid()

	if file, err := os.Create(filePath); err == nil {
		defer file.Close()

		_, err = file.WriteString(fmt.Sprintf("%d", pid))

		return err
	} else {
		return err
	}
}

func main() {
	http.HandleFunc("/", echoHandler)

	if err := writePidToFile("/tmp/vsock_echo.pid"); err == nil {
		defer os.Remove("/tmp/vsock_echo.pid")

		if listener, err := vsock.Listen(vsockPort, &vsock.Config{}); err != nil {
			log.Fatalf("Failed to create VSOCK listener: %v", err)
		} else {
			defer listener.Close()

			log.Printf("Serving HTTP on VSOCK port %d", vsockPort)

			if err = http.Serve(listener, nil); err != nil {
				log.Fatalf("Failed to serve HTTP: %v", err)
			}
		}
	} else {
		log.Fatalf("Failed to write PID to file: %v", err)
	}
}
