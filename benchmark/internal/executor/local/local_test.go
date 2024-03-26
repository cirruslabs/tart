package local_test

import (
	"context"
	"github.com/cirruslabs/tart/benchmark/internal/executor/local"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
	"testing"
)

func TestLocal(t *testing.T) {
	local, err := local.New(zap.NewNop())
	require.NoError(t, err)

	output, err := local.Run(context.Background(), "echo \"this is a test\"")
	require.NoError(t, err)
	require.Equal(t, "this is a test\n", string(output))

	require.NoError(t, local.Close())
}
