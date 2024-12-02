package tart_test

import (
	"context"
	"github.com/cirruslabs/tart/benchmark/internal/executor/tart"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
	"testing"
)

func TestTart(t *testing.T) {
	ctx := context.Background()

	tart, err := tart.New(ctx, "ghcr.io/cirruslabs/macos-sonoma-base:latest", nil, zap.NewNop())
	require.NoError(t, err)

	output, err := tart.Run(ctx, "echo \"this is a test\"")
	require.NoError(t, err)
	require.Equal(t, "this is a test\n", string(output))

	require.NoError(t, tart.Close())
}
