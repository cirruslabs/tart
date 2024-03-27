package local

import (
	"bytes"
	"context"
	"go.uber.org/zap"
	"go.uber.org/zap/zapio"
	"io"
	"os/exec"
)

type Local struct {
	logger *zap.Logger
}

func New(logger *zap.Logger) (*Local, error) {
	return &Local{
		logger: logger,
	}, nil
}

func (local *Local) Name() string {
	return "local"
}

func (local *Local) Run(ctx context.Context, command string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "zsh", "-c", command)

	loggerWriter := &zapio.Writer{Log: local.logger, Level: zap.DebugLevel}
	stdoutBuf := &bytes.Buffer{}

	cmd.Stdout = io.MultiWriter(stdoutBuf, loggerWriter)
	cmd.Stderr = loggerWriter

	err := cmd.Run()

	return stdoutBuf.Bytes(), err
}

func (local *Local) Close() error {
	return nil
}
