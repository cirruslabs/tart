package tart

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"github.com/avast/retry-go/v4"
	"github.com/google/uuid"
	"go.uber.org/zap"
	"golang.org/x/crypto/ssh"
	"net"
	"strings"
	"time"
)

const baseImage = "ghcr.io/cirruslabs/macos-sonoma-base:latest"

type Tart struct {
	vmRunCancel context.CancelFunc
	vmName      string
	sshClient   *ssh.Client
	logger      *zap.Logger
}

func New(ctx context.Context, logger *zap.Logger) (*Tart, error) {
	tart := &Tart{
		vmName: fmt.Sprintf("tart-benchmark-%s", uuid.NewString()),
		logger: logger,
	}

	if err := Cmd(ctx, tart.logger, "pull", baseImage); err != nil {
		return nil, err
	}

	if err := Cmd(ctx, tart.logger, "clone", baseImage, tart.vmName); err != nil {
		return nil, err
	}

	vmRunCtx, vmRunCancel := context.WithCancel(ctx)
	tart.vmRunCancel = vmRunCancel

	go func() {
		_ = Cmd(vmRunCtx, tart.logger, "run", "--no-graphics", tart.vmName)
	}()

	ip, err := CmdWithOutput(ctx, tart.logger, "ip", "--wait", "60", tart.vmName)
	if err != nil {
		return nil, tart.Close()
	}

	err = retry.Do(func() error {
		dialer := net.Dialer{
			Timeout: 1 * time.Second,
		}

		addr := fmt.Sprintf("%s:22", strings.TrimSpace(ip))

		netConn, err := dialer.DialContext(ctx, "tcp", addr)
		if err != nil {
			return err
		}

		sshConn, chans, reqs, err := ssh.NewClientConn(netConn, addr, &ssh.ClientConfig{
			User: "admin",
			Auth: []ssh.AuthMethod{
				ssh.Password("admin"),
			},
			HostKeyCallback: func(_ string, _ net.Addr, _ ssh.PublicKey) error {
				return nil
			},
		})
		if err != nil {
			return err
		}

		tart.sshClient = ssh.NewClient(sshConn, chans, reqs)

		return nil
	}, retry.RetryIf(func(err error) bool {
		return !errors.Is(err, context.Canceled)
	}))
	if err != nil {
		return nil, tart.Close()
	}

	return tart, nil
}

func (tart *Tart) Name() string {
	return "Tart"
}

func (tart *Tart) Run(ctx context.Context, command string) ([]byte, error) {
	sshSession, err := tart.sshClient.NewSession()
	if err != nil {
		return nil, err
	}

	// Work around x/crypto/ssh not being context.Context-friendly (e.g. https://github.com/golang/go/issues/20288)
	monitorCtx, monitorCancel := context.WithCancel(ctx)
	go func() {
		<-monitorCtx.Done()
		_ = sshSession.Close()
	}()
	defer monitorCancel()

	stdoutBuf := &bytes.Buffer{}

	sshSession.Stdin = bytes.NewBufferString(command)
	sshSession.Stdout = stdoutBuf

	if err := sshSession.Shell(); err != nil {
		return nil, err
	}

	if err := sshSession.Wait(); err != nil {
		return nil, err
	}

	return stdoutBuf.Bytes(), nil
}

func (tart *Tart) Close() error {
	if tart.sshClient != nil {
		_ = tart.sshClient.Close()
	}

	tart.vmRunCancel()
	_ = Cmd(context.Background(), tart.logger, "delete", tart.vmName)

	return nil
}
