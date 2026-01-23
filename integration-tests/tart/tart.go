package tart

import (
	"bytes"
	"errors"
	"fmt"
	"os/exec"
	"strings"
	"testing"
)

const tartCommandName = "tart"

var (
	ErrTartNotFound = errors.New("tart command not found")
	ErrTartFailed   = errors.New("tart command returned non-zero exit code")
)

func Tart(t *testing.T, args ...string) (string, string, error) {
	t.Helper()

	cmd := exec.CommandContext(t.Context(), tartCommandName, args...)

	var stdout, stderr bytes.Buffer

	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		if errors.Is(err, exec.ErrNotFound) {
			return "", "", fmt.Errorf("%w: %s command not found in PATH, make sure Tart is installed",
				ErrTartNotFound, tartCommandName)
		}

		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			// Tart command failed, redefine the error to be the Tart-specific output
			err = fmt.Errorf("%w: %q", ErrTartFailed, firstNonEmptyLine(stderr.String(), stdout.String()))
		}
	}

	return stdout.String(), stderr.String(), err
}

func firstNonEmptyLine(outputs ...string) string {
	for _, output := range outputs {
		for _, line := range strings.Split(output, "\n") {
			if line != "" {
				return line
			}
		}
	}

	return ""
}
