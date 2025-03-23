package tart

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"github.com/avast/retry-go/v4"
	"github.com/google/uuid"
	"github.com/shirou/gopsutil/mem"
	"go.uber.org/zap"
	"go.uber.org/zap/zapio"
	"golang.org/x/crypto/ssh"
	"io"
	"net"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type Tart struct {
	vmRunCancel context.CancelFunc
	vmName      string
	sshClient   *ssh.Client
	logger      *zap.Logger
}

func New(ctx context.Context, image string, runArgsExtra []string, logger *zap.Logger) (*Tart, error) {
	tart := &Tart{
		vmName: fmt.Sprintf("tart-benchmark-%s", uuid.NewString()),
		logger: logger,
	}

	if err := Cmd(ctx, tart.logger, "pull", image); err != nil {
		return nil, err
	}

	if err := Cmd(ctx, tart.logger, "clone", image, tart.vmName); err != nil {
		return nil, err
	}

	vmStat, err := mem.VirtualMemory()
	if err != nil {
		return nil, err
	}

	cpus := strconv.Itoa(runtime.NumCPU())
	memory := strconv.FormatUint(vmStat.Total/1024/1024, 10)
	logger.Info("Setting resources", zap.String("cpus", cpus), zap.String("memory", memory))
	setResourcesArguments := []string{
		"set", tart.vmName,
		"--cpu", cpus,
		"--memory", memory,
	}
	if err := Cmd(ctx, tart.logger, setResourcesArguments...); err != nil {
		return nil, err
	}

	vmRunCtx, vmRunCancel := context.WithCancel(ctx)
	tart.vmRunCancel = vmRunCancel

	go func() {
		runArgs := []string{"run", "--no-graphics", tart.vmName}

		runArgs = append(runArgs, runArgsExtra...)

		_ = Cmd(vmRunCtx, tart.logger, runArgs...)
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

	loggerWriter := &zapio.Writer{Log: tart.logger, Level: zap.DebugLevel}
	stdoutBuf := &bytes.Buffer{}

	sshSession.Stdin = bytes.NewBufferString(command)
	sshSession.Stdout = io.MultiWriter(stdoutBuf, loggerWriter)
	sshSession.Stderr = loggerWriter

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
