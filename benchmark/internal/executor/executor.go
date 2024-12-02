package executor

import (
	"context"
)

type Executor interface {
	Run(ctx context.Context, command string) ([]byte, error)
	Close() error
}
