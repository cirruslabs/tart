package xcode_test

import (
	"fmt"
	"github.com/cirruslabs/tart/benchmark/internal/command/xcode"
	"github.com/stretchr/testify/require"
	"testing"
	"time"
)

func TestParseOutput(t *testing.T) {
	result, err := xcode.ParseOutput(`** BUILD SUCCEEDED ** [219.713 sec]

System Version: 14.6
Xcode 15.4
Hardware Overview
      Model Name: Apple Virtual Machine 1
      Model Identifier: VirtualMac2,1
      Total Number of Cores: 4
      Memory: 8 GB

✅ XcodeBenchmark has completed
1️⃣  Take a screenshot of this window (Cmd + Shift + 4 + Space) and resize to include:
	- Build Time (See ** BUILD SUCCEEDED ** [XYZ sec])
	- System Version
	- Xcode Version
	- Hardware Overview
	- Started 13:46:20
	- Ended   13:50:02
	- Date Thu Jan 16 13:50:02 UTC 2025

2️⃣  Share your results at https://github.com/devMEremenko/XcodeBenchmark
`)
	require.NoError(t, err)
	fmt.Println(result)
	require.Equal(t, 222*time.Second, result.Ended.Sub(result.Started))
}
