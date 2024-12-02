package fio

import (
	"encoding/json"
	"fmt"
	executorpkg "github.com/cirruslabs/tart/benchmark/internal/executor"
	"github.com/cirruslabs/tart/benchmark/internal/executor/local"
	"github.com/cirruslabs/tart/benchmark/internal/executor/tart"
	"github.com/dustin/go-humanize"
	"github.com/gosuri/uitable"
	"github.com/spf13/cobra"
	"go.uber.org/zap"
	"go.uber.org/zap/zapio"
	"os"
	"os/exec"
)

var debug bool
var image string
var prepare string

func NewCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "fio",
		Short: "run Flexible I/O tester (fio) benchmarks",
		RunE:  run,
	}

	cmd.Flags().BoolVar(&debug, "debug", false, "enable debug logging")
	cmd.Flags().StringVar(&image, "image", "ghcr.io/cirruslabs/macos-sonoma-base:latest", "image to use for testing")
	cmd.Flags().StringVar(&prepare, "prepare", "", "command to run before running each benchmark")

	return cmd
}

func run(cmd *cobra.Command, args []string) error {
	config := zap.NewProductionConfig()
	if debug {
		config.Level = zap.NewAtomicLevelAt(zap.DebugLevel)
	}
	logger, err := config.Build()
	if err != nil {
		return err
	}
	defer func() {
		_ = logger.Sync()
	}()

	var executorInitializers = []struct {
		Name string
		Fn   func() (executorpkg.Executor, error)
	}{
		{
			Name: "local",
			Fn: func() (executorpkg.Executor, error) {
				return local.New(logger)
			},
		},
		{
			Name: "Tart",
			Fn: func() (executorpkg.Executor, error) {
				return tart.New(cmd.Context(), image, nil, logger)
			},
		},
		{
			Name: "Tart (--root-disk-opts=\"sync=none\")",
			Fn: func() (executorpkg.Executor, error) {
				return tart.New(cmd.Context(), image, []string{
					"--root-disk-opts",
					"sync=none",
				}, logger)
			},
		},
		{
			Name: "Tart (--root-disk-opts=\"sync=none,caching=cached\")",
			Fn: func() (executorpkg.Executor, error) {
				return tart.New(cmd.Context(), image, []string{
					"--root-disk-opts",
					"sync=none,caching=cached",
				}, logger)
			},
		},
	}

	table := uitable.New()
	table.AddRow("Name", "Executor", "Bandwidth", "I/O operations")

	for _, benchmark := range benchmarks {
		for _, executorInitializer := range executorInitializers {
			if prepare != "" {
				shell := "/bin/sh"

				if shellFromEnv, ok := os.LookupEnv("SHELL"); ok {
					shell = shellFromEnv
				}

				logger.Sugar().Infof("running prepare command %q using shell %q",
					prepare, shell)

				cmd := exec.CommandContext(cmd.Context(), shell, "-c", prepare)

				loggerWriter := &zapio.Writer{Log: logger, Level: zap.DebugLevel}

				cmd.Stdout = loggerWriter
				cmd.Stderr = loggerWriter

				if err := cmd.Run(); err != nil {
					return fmt.Errorf("failed to run prepare command %q: %v", prepare, err)
				}
			}

			logger.Sugar().Infof("initializing executor %s", executorInitializer.Name)

			executor, err := executorInitializer.Fn()
			if err != nil {
				return err
			}

			logger.Sugar().Infof("installing Flexible I/O tester (fio) on executor %s",
				executorInitializer.Name)

			if _, err := executor.Run(cmd.Context(), "brew install fio"); err != nil {
				return err
			}

			logger.Sugar().Infof("running benchmark %q on %s executor", benchmark.Name,
				executorInitializer.Name)

			stdout, err := executor.Run(cmd.Context(), benchmark.Command)
			if err != nil {
				return err
			}

			var fioResult Result

			if err := json.Unmarshal(stdout, &fioResult); err != nil {
				return err
			}

			if len(fioResult.Jobs) != 1 {
				return fmt.Errorf("expected exactly 1 job from fio's JSON output, got %d",
					len(fioResult.Jobs))
			}

			job := fioResult.Jobs[0]

			writeBandwidth := humanize.Bytes(uint64(job.Write.BW)*humanize.KByte) + "/s"
			writeIOPS := humanize.SIWithDigits(job.Write.IOPS, 2, "IOPS")

			logger.Sugar().Infof("write bandwidth: %s, write IOPS: %s\n", writeBandwidth, writeIOPS)

			table.AddRow(benchmark.Name, executorInitializer.Name, writeBandwidth, writeIOPS)

			if err := executor.Close(); err != nil {
				return fmt.Errorf("failed to close executor %s: %w",
					executorInitializer.Name, err)
			}
		}
	}

	fmt.Println(table.String())

	return nil
}
