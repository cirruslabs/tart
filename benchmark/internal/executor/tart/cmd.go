package tart

import (
	"bytes"
	"context"
	"go.uber.org/zap"
	"go.uber.org/zap/zapio"
	"io"
	"os/exec"
	"strings"
)

const tartBinaryName = "tart"

func Cmd(ctx context.Context, logger *zap.Logger, args ...string) error {
	_, err := CmdWithOutput(ctx, logger, args...)

	return err
}

func CmdWithOutput(ctx context.Context, logger *zap.Logger, args ...string) (string, error) {
	logger.Sugar().Debugf("running %s %s", tartBinaryName, strings.Join(args, " "))

	cmd := exec.CommandContext(ctx, tartBinaryName, args...)

	loggerWriter := &zapio.Writer{Log: logger, Level: zap.DebugLevel}
	stdoutBuf := &bytes.Buffer{}

	cmd.Stdout = io.MultiWriter(stdoutBuf, loggerWriter)
	cmd.Stderr = loggerWriter

	err := cmd.Run()

	return stdoutBuf.String(), err
}
