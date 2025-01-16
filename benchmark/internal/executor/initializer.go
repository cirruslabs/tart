package executor

import (
	"context"
	"github.com/cirruslabs/tart/benchmark/internal/executor/local"
	"github.com/cirruslabs/tart/benchmark/internal/executor/tart"
	"go.uber.org/zap"
)

type Initializer struct {
	Name string
	Fn   func() (Executor, error)
}

func DefaultInitializers(ctx context.Context, image string, logger *zap.Logger) []Initializer {
	return []Initializer{
		{
			Name: "local",
			Fn: func() (Executor, error) {
				return local.New(logger)
			},
		},
		{
			Name: "Tart",
			Fn: func() (Executor, error) {
				return tart.New(ctx, image, nil, logger)
			},
		},
		{
			Name: "Tart (--root-disk-opts=\"sync=none\")",
			Fn: func() (Executor, error) {
				return tart.New(ctx, image, []string{
					"--root-disk-opts",
					"sync=none",
				}, logger)
			},
		},
		{
			Name: "Tart (--root-disk-opts=\"caching=cached\")",
			Fn: func() (Executor, error) {
				return tart.New(ctx, image, []string{
					"--root-disk-opts",
					"caching=cached",
				}, logger)
			},
		},
		{
			Name: "Tart (--root-disk-opts=\"sync=none,caching=cached\")",
			Fn: func() (Executor, error) {
				return tart.New(ctx, image, []string{
					"--root-disk-opts",
					"sync=none,caching=cached",
				}, logger)
			},
		},
	}
}
