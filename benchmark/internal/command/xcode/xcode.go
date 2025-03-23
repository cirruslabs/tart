package xcode

import (
	"fmt"
	executorpkg "github.com/cirruslabs/tart/benchmark/internal/executor"
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
		Use:   "xcode",
		Short: "run XCode benchmarks",
		RunE:  run,
	}

	cmd.Flags().BoolVar(&debug, "debug", false, "enable debug logging")
	cmd.Flags().StringVar(&image, "image", "ghcr.io/cirruslabs/macos-sequoia-xcode:latest", "image to use for testing")
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

	table := uitable.New()
	table.AddRow("Name", "Executor", "Time")

	for _, benchmark := range benchmarks {
		for _, executorInitializer := range executorpkg.DefaultInitializers(cmd.Context(), image, logger) {
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

			logger.Sugar().Infof("running benchmark %q on %s executor", benchmark.Name,
				executorInitializer.Name)

			stdout, err := executor.Run(cmd.Context(), benchmark.Command)
			if err != nil {
				return err
			}

			output, err := ParseOutput(string(stdout))
			if err != nil {
				return err
			}

			duration := output.Ended.Sub(output.Started)

			logger.Sugar().Infof("Xcode benchmark duration: %s", duration)

			table.AddRow(benchmark.Name, executorInitializer.Name, duration)

			if err := executor.Close(); err != nil {
				return fmt.Errorf("failed to close executor %s: %w",
					executorInitializer.Name, err)
			}
		}
	}

	fmt.Println(table.String())

	return nil
}
